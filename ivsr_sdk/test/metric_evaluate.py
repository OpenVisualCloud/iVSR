#!/usr/bin/env python
# coding=utf-8
import numpy as np
import torch
import cv2

import mmcv
from torchvision.utils import make_grid
import math
import argparse
import os
import csv
def tensor2img(tensor, out_type=np.uint8, min_max=(0, 1)):
    """Convert torch Tensors into image numpy arrays. from: mmedit/core/misc.py

    After clamping to (min, max), image values will be normalized to [0, 1].

    For differnet tensor shapes, this function will have different behaviors:

        1. 4D mini-batch Tensor of shape (N x 3/1 x H x W):
            Use `make_grid` to stitch images in the batch dimension, and then
            convert it to numpy array.
        2. 3D Tensor of shape (3/1 x H x W) and 2D Tensor of shape (H x W):
            Directly change to numpy array.

    Note that the image channel in input tensors should be RGB order. This
    function will convert it to cv2 convention, i.e., (H x W x C) with BGR
    order.

    Args:
        tensor (Tensor | list[Tensor]): Input tensors.
        out_type (numpy type): Output types. If ``np.uint8``, transform outputs
            to uint8 type with range [0, 255]; otherwise, float type with
            range [0, 1]. Default: ``np.uint8``.
        min_max (tuple): min and max values for clamp.

    Returns:
        (Tensor | list[Tensor]): 3D ndarray of shape (H x W x C) or 2D ndarray
        of shape (H x W).
    """
    if not (torch.is_tensor(tensor) or
            (isinstance(tensor, list)
             and all(torch.is_tensor(t) for t in tensor))):
        raise TypeError(
            f'tensor or list of tensors expected, got {type(tensor)}')

    if torch.is_tensor(tensor):
        tensor = [tensor]
    result = []
    for _tensor in tensor:
        # Squeeze two times so that:
        # 1. (1, 1, h, w) -> (h, w) or
        # 3. (1, 3, h, w) -> (3, h, w) or
        # 2. (n>1, 3/1, h, w) -> (n>1, 3/1, h, w)
        _tensor = _tensor.squeeze(0).squeeze(0)
        _tensor = _tensor.float().detach().cpu().clamp_(*min_max)
        _tensor = (_tensor - min_max[0]) / (min_max[1] - min_max[0])
        n_dim = _tensor.dim()
        if n_dim == 4:
            img_np = make_grid(
                _tensor, nrow=int(math.sqrt(_tensor.size(0))),
                normalize=False).numpy()
            img_np = np.transpose(img_np[[2, 1, 0], :, :], (1, 2, 0))
        elif n_dim == 3:
            img_np = _tensor.numpy()
            img_np = np.transpose(img_np[[2, 1, 0], :, :], (1, 2, 0))
        elif n_dim == 2:
            img_np = _tensor.numpy()
        else:
            raise ValueError('Only support 4D, 3D or 2D tensor. '
                             f'But received with dimension: {n_dim}')
        if out_type == np.uint8:
            # Unlike MATLAB, numpy.unit8() WILL NOT round by default.
            img_np = (img_np * 255.0).round()
        img_np.astype(out_type)
        result.append(img_np)
    result = result[0] if len(result) == 1 else result
    return result

def reorder_image(img, input_order='HWC'):
    """Reorder images to 'HWC' order.

    If the input_order is (h, w), return (h, w, 1);
    If the input_order is (c, h, w), return (h, w, c);
    If the input_order is (h, w, c), return as it is.

    Args:
        img (ndarray): Input image.
        input_order (str): Whether the input order is 'HWC' or 'CHW'.
            If the input image shape is (h, w), input_order will not have
            effects. Default: 'HWC'.

    Returns:
        ndarray: reordered image.
    """

    if input_order not in ['HWC', 'CHW']:
        raise ValueError(
            f'Wrong input_order {input_order}. Supported input_orders are '
            '"HWC" and "CHW"')
    if len(img.shape) == 2:
        img = img[..., None]
        return img
    if input_order == 'CHW':
        img = img.transpose(1, 2, 0)
    return img

def psnr(img1, img2, crop_border=0, input_order='HWC', convert_to=None):
    """Calculate PSNR (Peak Signal-to-Noise Ratio).

    Ref: https://en.wikipedia.org/wiki/Peak_signal-to-noise_ratio

    Args:
        img1 (ndarray): Images with range [0, 255].
        img2 (ndarray): Images with range [0, 255].
        crop_border (int): Cropped pixels in each edges of an image. These
            pixels are not involved in the PSNR calculation. Default: 0.
        input_order (str): Whether the input order is 'HWC' or 'CHW'.
            Default: 'HWC'.
        convert_to (str): Whether to convert the images to other color models.
            If None, the images are not altered. When computing for 'Y',
            the images are assumed to be in BGR order. Options are 'Y' and
            None. Default: None.

    Returns:
        float: psnr result.
    """

    assert img1.shape == img2.shape, (
        f'Image shapes are differnet: {img1.shape}, {img2.shape}.')
    if input_order not in ['HWC', 'CHW']:
        raise ValueError(
            f'Wrong input_order {input_order}. Supported input_orders are '
            '"HWC" and "CHW"')
    img1 = reorder_image(img1, input_order=input_order)
    img2 = reorder_image(img2, input_order=input_order)

    img1, img2 = img1.astype(np.float32), img2.astype(np.float32)
    if isinstance(convert_to, str) and convert_to.lower() == 'y':
        img1 = mmcv.bgr2ycbcr(img1 / 255., y_only=True) * 255.
        img2 = mmcv.bgr2ycbcr(img2 / 255., y_only=True) * 255.
    elif convert_to is not None:
        raise ValueError('Wrong color model. Supported values are '
                         '"Y" and None.')

    if crop_border != 0:
        img1 = img1[crop_border:-crop_border, crop_border:-crop_border, None]
        img2 = img2[crop_border:-crop_border, crop_border:-crop_border, None]

    mse_value = np.mean((img1 - img2)**2)
    if mse_value == 0:
        # return float('inf')
        return float(10e5)
    return 20. * np.log10(255. / np.sqrt(mse_value))

def _ssim(img1, img2):
    """Calculate SSIM (structural similarity) for one channel images.

    It is called by func:`calculate_ssim`.

    Args:
        img1, img2 (ndarray): Images with range [0, 255] with order 'HWC'.

    Returns:
        float: ssim result.
    """

    C1 = (0.01 * 255)**2
    C2 = (0.03 * 255)**2

    img1 = img1.astype(np.float64)
    img2 = img2.astype(np.float64)
    kernel = cv2.getGaussianKernel(11, 1.5)
    window = np.outer(kernel, kernel.transpose())

    mu1 = cv2.filter2D(img1, -1, window)[5:-5, 5:-5]
    mu2 = cv2.filter2D(img2, -1, window)[5:-5, 5:-5]
    mu1_sq = mu1**2
    mu2_sq = mu2**2
    mu1_mu2 = mu1 * mu2
    sigma1_sq = cv2.filter2D(img1**2, -1, window)[5:-5, 5:-5] - mu1_sq
    sigma2_sq = cv2.filter2D(img2**2, -1, window)[5:-5, 5:-5] - mu2_sq
    sigma12 = cv2.filter2D(img1 * img2, -1, window)[5:-5, 5:-5] - mu1_mu2

    ssim_map = ((2 * mu1_mu2 + C1) *
                (2 * sigma12 + C2)) / ((mu1_sq + mu2_sq + C1) *
                                       (sigma1_sq + sigma2_sq + C2))
    return ssim_map.mean()


def ssim(img1, img2, crop_border=0, input_order='HWC', convert_to=None):
    """Calculate SSIM (structural similarity).

    Ref:
    Image quality assessment: From error visibility to structural similarity

    The results are the same as that of the official released MATLAB code in
    https://ece.uwaterloo.ca/~z70wang/research/ssim/.

    For three-channel images, SSIM is calculated for each channel and then
    averaged.

    Args:
        img1 (ndarray): Images with range [0, 255].
        img2 (ndarray): Images with range [0, 255].
        crop_border (int): Cropped pixels in each edges of an image. These
            pixels are not involved in the SSIM calculation. Default: 0.
        input_order (str): Whether the input order is 'HWC' or 'CHW'.
            Default: 'HWC'.
        convert_to (str): Whether to convert the images to other color models.
            If None, the images are not altered. When computing for 'Y',
            the images are assumed to be in BGR order. Options are 'Y' and
            None. Default: None.

    Returns:
        float: ssim result.
    """

    assert img1.shape == img2.shape, (
        f'Image shapes are differnet: {img1.shape}, {img2.shape}.')
    if input_order not in ['HWC', 'CHW']:
        raise ValueError(
            f'Wrong input_order {input_order}. Supported input_orders are '
            '"HWC" and "CHW"')
    img1 = reorder_image(img1, input_order=input_order)
    img2 = reorder_image(img2, input_order=input_order)

    if isinstance(convert_to, str) and convert_to.lower() == 'y':
        img1, img2 = img1.astype(np.float32), img2.astype(np.float32)
        img1 = mmcv.bgr2ycbcr(img1 / 255., y_only=True) * 255.
        img2 = mmcv.bgr2ycbcr(img2 / 255., y_only=True) * 255.
        img1 = np.expand_dims(img1, axis=2)
        img2 = np.expand_dims(img2, axis=2)
    elif convert_to is not None:
        raise ValueError('Wrong color model. Supported values are '
                         '"Y" and None')

    if crop_border != 0:
        img1 = img1[crop_border:-crop_border, crop_border:-crop_border, None]
        img2 = img2[crop_border:-crop_border, crop_border:-crop_border, None]

    ssims = []
    for i in range(img1.shape[2]):
        ssims.append(_ssim(img1[..., i], img2[..., i]))
    return np.array(ssims).mean()

def get_file_path(data_folder):
    files = []
    all_file_in_dir = os.listdir(data_folder)
    all_file_in_dir.sort(key=lambda x:int(x.split('.')[0]))
    for name in all_file_in_dir:
        file_path = os.path.join(data_folder,name)
        if cv2.haveImageReader(file_path):
            files.append(file_path)
    return files


def getImage(filepath):
    image = cv2.cvtColor(cv2.imread(filepath), cv2.COLOR_BGR2RGB)
    return image


def parse_args():
    parser = argparse.ArgumentParser(description='Evaluation in Metrics')
    parser.add_argument(
        '--test_data_path',
        default='',
        type=str,
        help='Need. Data in folder needs to be evaluated')
    parser.add_argument(
        '--ref_data_path',
        default='',
        type=str,
        help='Need. Data in folder acts as a reference') 
    parser.add_argument(
        '--output_file_name',
        default='quality.csv',
        type=str,
        help='Optional. Results saved file name') 
    parser.add_argument(
        '--simple_process',
        action='store_true',
        help='Optional. Directly give out the test folder and reference folder to be processed.')
    parser.add_argument(
        '--multi_process',
        action='store_true',
        help='Optional. Perform metric tests in multi-folders.')
    parser.add_argument(
        '--simple_compare',
        action='store_true',
        help='Optional. Bit-wise compare between two folders of data.')
    args = parser.parse_args()
    return args

def simple_compare(test_path,ref_path):
    print(f"Bit-wise compareof data:{test_path} on {ref_path}")
    test_files = get_file_path(test_path)
    length = len(test_files)//3*3
    test_files = test_files[:length]
    ref_files = get_file_path(ref_path)[:length]
    
    diff_list = []
    for idx in range(len(test_files)):
        test = test_files[idx]
        ref =  ref_files[idx]
        test_img = getImage(test)
        ref_img = getImage(ref)
        diff = test_img - ref_img
        print(f"{idx} Avg.diff:{np.mean(diff)}")
        print(f"{idx} Max.diff:{np.max(diff)}")
        diff_list.append(diff)
    avg_diff = np.mean(diff_list)
    print(f"Average Diff:{avg_diff}")

    
def single_process(test_path,ref_path):
    print(f"Evaluate the quality of data:{test_path} on {ref_path}")
    test_files = get_file_path(test_path)
    length = len(test_files)//3*3
    test_files = test_files[:length]
    ref_files = get_file_path(ref_path)[:length]
    # assert len(test_files) == len(ref_files), (
    #             f'Number of test data files {len(test_files)} are not consistent with that of reference data files {len(ref_files)}')

    psnr_list = []
    ssim_list = []
    # for (test,ref) in zip(test_files,ref_files):
    for idx in range(len(test_files)):
        test = test_files[idx]
        ref =  ref_files[idx]
        test_img = getImage(test)
        ref_img = getImage(ref)
        psnr_ = psnr(test_img,ref_img)
        ssim_ = ssim(test_img,ref_img)
        print(f"PSNR:{psnr_}, SSIM:{ssim_}")
        psnr_list.append(psnr_)
        ssim_list.append(ssim_)
    avg_psnr = np.mean(psnr_list)
    avg_ssim = np.mean(ssim_list)
    print(f"Average PSNR:{avg_psnr}")
    print(f"Average SSIM:{avg_ssim}")
    return avg_psnr,avg_ssim


def multi_process(test_path, ref_path,output_file_name):
    # process formatted outputs e.g. output from perf_test.sh
    
    # data path example:
    # test_path = "/home/media/longkun/ivsr_sdk/build/samples/outputs"
    # non-ani_ref_path = "/home/media/longkun/basicvsr/dataset/cuc/HR"
    # ani_ref_path = "/home/media/longkun/basicvsr/dataset/cuc/HR"

    fo = open(output_file_name, "w", newline='')
    header = ["Device", "Model Type", "Model","Data","PSNR","SSIM"]
    writer = csv.writer(fo)
    writer.writerow(header)

    devices = os.listdir(test_path)
    devices = ["CPU","GPU"]
    results_out = []
    for device in devices:  # CPU GPU
        model_type_path = os.path.join(test_path,device)
        model_types = os.listdir(model_type_path)
        for model_type in model_types: # ani-model non-ani model
            model_configs_path = os.path.join(model_type_path,model_type)
            models = os.listdir(model_configs_path)
            print(f"Model type:{models}")
            for model in models: # FP32 w/o cp, FP32 w/ cp INT8 w/ cp
                model_path = os.path.join(model_configs_path,model)
                data_folders = os.listdir(model_path)
                print(f"Model model_path:{model_path}")
                for folder in [data_folders]: # 000,001,004,006
                    test_file_path = os.path.join(model_path,folder)
                    ref_file_path = os.path.join(ref_path,folder)
                    print(f"Test data path:{test_file_path}")
                    print(f"Ref data path:{ref_file_path}")
                    psnr,ssim = single_process(test_file_path,ref_file_path)
                    row=[device,model_type,model,folder,psnr,ssim]
                    print(f"{row}")
                    writer.writerow(row)
    fo.close()


if __name__ == '__main__':
    args = parse_args()
    test_path = args.test_data_path
    ref_path = args.ref_data_path
    if args.simple_process:
        single_process(test_path,ref_path)
    elif args.multi_process:
        multi_process(test_path,ref_path,args.output_file_name)
    elif args.simple_compare:
        simple_compare(test_path,ref_path)
    else:
        print("Please select and input a metirc test mode in args.")




