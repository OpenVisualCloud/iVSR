from argparse import ArgumentParser
import imageio.v3 as iio
import numpy as np

if __name__ == '__main__':

    parser = ArgumentParser(description='')
    parser.add_argument('im0', type=str)
    parser.add_argument('im1', type=str)
    args = parser.parse_args()

    im0 = iio.imread(args.im0)
    im1 = iio.imread(args.im1)
    
    diff_abs = np.abs(im1.astype(np.int16) - im0.astype(np.int16))
    diff_ratio = diff_abs.sum() / diff_abs.size

    if diff_abs.max() < 2 and diff_ratio < 0.01:
        print(r"test_case: svp test, duration: n/a, result: [Pass], error_info: same as reference image")
    else:
        print(r"test_case: svp test, duration: n/a, result: [Fail], error_info: diff w/ reference image")
