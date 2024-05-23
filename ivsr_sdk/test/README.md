# iVSR SDK tests


In this folder, it contains the tests defined for iVSR SDK.

##  **Unit tests**


There are some unit tests for the iVSR API. You can reach the unit tests from `/workspace/ivsr/ivsr_sdk/bin/vsr_unit_test` if it was built in docker container.<br />

Since model is essential for inference, you need to prepare models (*.bin and *.xml ) to the same path of `vsr_unit_test` and rename the model files to "test_with_custom_op.xml" and "test_with_custom_op.bin". And put the extension lib file "libcustom_extension.so" and clDNN custom operation file "flow_warp.xml/flow_warp.cl" in the same folder as `vsr_unit_test`.<br />

There are tests for inference running on multiple GPUs, so make sure your hardware has at least two GPUs pre-installed, and pre-configured according to [GPU Enabling instruction](../ENVIRONMENT.md#install-gpu-driver).<br />

You can perform unit tests by runing the following command:

```bash
./vsr_unit_test
```

Then you can obtain the test results with status <font color="#00dd00">PASSED</font> or <font color="#dd0000">FAILED</font>.<br />

NOTE: The unit tests don't cover all APIs implemented in the SDK yet.
