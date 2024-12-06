from argparse import ArgumentParser
import imageio.v3 as iio
import numpy as np

if __name__ == '__main__':

    parser = ArgumentParser(description='')
    parser.add_argument('im0', type=str)
    parser.add_argument('im1', type=str)
    parser.add_argument('--criterion', required=False, type=str)
    args = parser.parse_args()

    im0 = iio.imread(args.im0)
    im1 = iio.imread(args.im1)

    diff_abs = np.abs(im1.astype(np.int16) - im0.astype(np.int16))
    diff_ratio = diff_abs.sum() / diff_abs.size

    diff_abs_max_criteria = 2
    diff_ratio_critera = 0.01

    if args.criterion:
        with open(args.criterion, 'r') as f:
            criterion_str = f.read()
        diff_abs_max_criteria, diff_ratio_critera = [eval(_) for _ in criterion_str.split(',')]

    print(diff_abs.max(), diff_ratio, diff_abs_max_criteria, diff_ratio_critera)

    if diff_abs.max() < diff_abs_max_criteria and diff_ratio < diff_ratio_critera:
        print(r"test_case: svp test, duration: n/a, result: [Pass], error_info: close to reference image")
    else:
        print(r"test_case: svp test, duration: n/a, result: [Fail], error_info: diff w/ reference image")
