# SVP test cases
* Please copy folder `svp_test` under `test_cases` into `ivsr_sdk` root directory
* Enter ivsr_sdk project directory
```shell
cd /<path_to_sdk>/ivsr_sdk
```
* Install required dependencies:
```shell
pip3 install -r ./svp_test/requirements.txt
```
## case 1: vsr_sample to test basic dyunetp model
* input image: ./svp_test/test_images/test_input.png
* model path: ./svp_test/dyunetp_2022.10/FP32/dyunetp.xml
* command line:
```shell
# create a temporary folder for output images if not created
mkdir -p outputs
# run vsr_sample command
./bin/vsr_sample --model_path=./svp_test/dyunetp_2022.10/FP32/dyunetp.xml --data_path=./svp_test/test_images --nig=1 --device=CPU --save_predictions=true --scale_factor=1
# rename the output image file
mv outputs/test_input.png outputs/test_output.png
```
* expected results:
```shell
# please run result checking script
python3 ./svp_test/check_ims.py ./svp_test/reference_images/reference_output.png ./outputs/test_output.png
```
Check log `test_case: svp test, duration: n/a, result: [Pass], error_info: close to reference image` and test case passed, or it is failed.
## case 2: ir_zip + vsr_sample single image test
* input image: ./svp_test/test_images/test_input.png
* model path: ./svp_test/dyunetp_2022.10/FP32/dyunetp.xml
* command line:
```shell
# enter ivsr_sdk project directory
cd /path_to_sdk
# run ir_zip command line
./bin/ir_zip -z ./svp_test/dyunetp_2022.10/FP32/dyunetp ./svp_test/dyunetp_zip 20241231
# run vsr_sample command to load zipped model
./bin/vsr_sample --model_path=./svp_test/dyunetp_zip --data_path=./svp_test/test_images --nig=1 --device=CPU --save_predictions=true --scale_factor=1
# rename the output image file
mv outputs/test_input.png outputs/test_output.png
```
* expected results:
```shell
# please run result checking script
python3 ./svp_test/check_ims.py ./svp_test/reference_images/reference_output.png ./outputs/test_output.png
```
Check log `test_case: svp test, duration: n/a, result: [Pass], error_info: close to reference image` and test case passed, or it is failed.
## case 3: vsr sample to test se model
* input image: ./svp_test/test_images/test_input.png
* model path: ./svp_test/se-qnet3m-16165-2024.04-f16/qnet3m_16165.xml
* command line:
```shell
# enter ivsr_sdk project directory
cd /path_to_sdk
# run vsr_sample command to load se model
./bin/vsr_sample --model_path=./svp_test/se-qnet3m-16165-2024.04-f16/qnet3m_16165.xml --data_path=./svp_test/test_images --nig=1 --device=CPU --save_predictions=true --scale_factor=1 --reshape_values="(1,3,1088,1920)"
# rename the output image file
mv outputs/test_input.png outputs/test_output.png
```
* expected results:
```shell
# please run result checking script
python3 ./svp_test/check_ims.py ./svp_test/se-qnet3m-16165-2024.04-f16/ref-out.png outputs/test_output.png --criterion ./svp_test/se-qnet3m-16165-2024.04-f16/criterion.txt

```
Check log `test_case: svp test, duration: n/a, result: [Pass], error_info: close to reference image` and test case passed, or it is failed.
## case 4: vsr sample to test basic dunet model
* input image: ./svp_test/test_images/test_input.png
* model path: ./svp_test/basic-dunet-2024.01/dunet.xml
* command line:
```shell
# enter ivsr_sdk project directory
cd /path_to_sdk
# run vsr_sample command to load dunet model
./bin/vsr_sample --model_path=./svp_test/basic-dunet-2024.01/dunet.xml --data_path=./svp_test/test_images --nig=1 --device=CPU --save_predictions=true --scale_factor=1 --reshape_values="(1,3,1088,1920)"
# rename the output image file
mv outputs/test_input.png outputs/test_output.png
```
* expected results:
```shell
# please run result checking script
python3 ./svp_test/check_ims.py ./svp_test/basic-dunet-2024.01/ref-out.png outputs/test_output.png --criterion ./svp_test/basic-dunet-2024.01/criterion.txt

```
Check log `test_case: svp test, duration: n/a, result: [Pass], error_info: close to reference image` and test case passed, or it is failed.
