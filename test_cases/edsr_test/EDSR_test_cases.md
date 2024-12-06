# EDSR test cases
* Enter ivsr_sdk project directory
* Compile project as following
```shell
cd /<path_to_sdk>/ivsr_sdk
mkdir build
cd build
cmake -DENABLE_LOG=ON -DENABLE_PERF=ON -DENABLE_TEST=OFF -DCMAKE_BUILD_TYPE=Release -DENABLE_THREADPROCESS=ON ..
```
## case 1: vsr_sample + EDSR model single image test
* input image: ./ivsr_sdk/test_cases/edsr_test/test_images/LR/LR_input.png
* model path: ./edsr.xml
* command line: 
```shell
# create a temporary folder for output images if not created
mkdir -p outputs
# run vsr_sample command
./bin/vsr_sample --model_path=./edsr.xml --data_path=./ivsr_sdk/test_cases/edsr_test/test_images/LR  --nig=1 --device=GPU --save_predictions=true --save_path=./outputs --normalize_factor=255.0
# rename the output image file
mv outputs/LR_input.png outputs/LR_output.png
#md5check
cd ivsr_sdk/test_cases/edsr_test
python check_results.py -i outputs/LR_output.png -o test_images/LR_ref.png
```
## case 2: vsr_sample + EDSR model single image with patch solution
* input image: ./ivsr_sdk/test_cases/edsr_test/test_images/HR/HR_input.png
* model path: ./edsr.xml
* command line: 
```shell
./bin/vsr_sample --model_path=./edsr.xml --data_path=./ivsr_sdk/test_cases/edsr_test/test_images/HR  --nig=1 --device=GPU --save_predictions=true --save_path=./outputs --normalize_factor=255.0
# rename the output image file
mv outputs/HR_input.png outputs/HR_output.png
#md5check
cd ivsr_sdk/test_cases/edsr_test
python check_results.py -i outputs/HR_output.png -o test_images/HR_ref.png
```
## case 3: vsr_sample + EDSR model single image multi GPU
* input image: ./ivsr_sdk/test_cases/edsr_test/test_images/HR/HR_input.png
* model path: ./edsr.xml
* command line: 
```shell
./bin/vsr_sample --model_path=./edsr.xml --data_path=./ivsr_sdk/test_cases/edsr_test/test_images/HR  --nig=1 --device=MULTI:GPU.0,GPU.1 --save_predictions=true --save_path=./outputs --normalize_factor=255.0
# rename the output image file
mv outputs/HR_input.png outputs/multigpu_output.png
#md5check
cd ivsr_sdk/test_cases/edsr_test
python check_results.py -i outputs/multigpu_output.png -o test_images/HR_ref.png
```
