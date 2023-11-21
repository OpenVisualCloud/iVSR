import hashlib

def parse_args():
    import argparse
    parser = argparse.ArgumentParser(description='Model Inference')
    parser.add_argument(
        '--input',
        '-i',
        type=str)

    parser.add_argument(
        '--output',
        '-o',
        type=str)

    args = parser.parse_args()
    return args

def img_to_md5(_path):
    fd = open(_path, 'rb')
    fmd5 = hashlib.md5(fd.read()).hexdigest()
    fd.close()
    return fmd5

def main():
    my_args = parse_args()
    input_path = my_args.input
    output_path = my_args.output
    input_md5 = img_to_md5(input_path)
    output_md5 = img_to_md5(output_path)
    if input_md5 != output_md5:
        print(r"test_case: EDSR test, duration: n/a, result: [Fail], error_info: diff w/ reference image")
    else: 
        print(r"test_case: svp test, duration: n/a, result: [Pass], info: same as reference image")



if __name__ == '__main__':
    main()