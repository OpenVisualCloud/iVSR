/* Copyright (C) 2025 Intel Corporation
 * SPDX-License-Identifier: BSD-3-Clause
 */

/**
 * @file ivsr_smart_patch.h
 * smart patch module API,
 * it is the wrapper of backend inference API.
 */

#ifndef SMART_PATCH_HPP
#define SMART_PATCH_HPP

#include<memory>
#include<vector>

#include "utils.hpp"

struct PatchConfig{
    int patchWidth;
    int patchHeight;
    int block_w;
    int block_h;
    int scale;
    int nif;
    int dims;
    PatchConfig(int w = 1920, int h = 1080, int pw = 1920, int ph = 1080, int b_w = 1,int b_h = 1,int s = 2,int n = 3,int d = 5)\
    :patchWidth(pw), patchHeight(ph),
    block_w(b_w), block_h(b_h), scale(s),
    nif(n), dims(d){}

    friend std::ostream& operator<<(std::ostream& os, const PatchConfig& cfg) {
        return os << "PatchConfig [width]:" << cfg.patchWidth << " [height]:" << cfg.patchHeight
                  << " [dims]:" << cfg.dims << " [scale]:" << cfg.scale << " [nif]:" << cfg.nif;
    }
};

class SmartPatch{
public:
    using Ptr = std::shared_ptr<SmartPatch>;
    SmartPatch(PatchConfig config, char* inBuf, char* outBuf , std::vector<int> _inputShape,bool flag);
 
    IBasicVSRStatus generatePatch();
    IBasicVSRStatus restoreImageFromPatches();
    std::vector<char*> getInputPatches();
    std::vector<char*> getOutputPatches();
    std::vector<int> getScores(){return _scores;}
    // char* getPatchfromId(int id){return _outputPtrList[id];}
    void setInput(char* inBuf){_inputPtr = inBuf;}
    void setOutput(char* outBuf){_outputPtr = outBuf;}
    char* getOutput(){return _outputPtr;}
    SmartPatch(const SmartPatch&) = delete;
    SmartPatch& operator=(const SmartPatch&) = delete;
    ~SmartPatch();
private:
    char* _inputPtr = nullptr; // inference input buffer ptr
    char* _outputPtr = nullptr; // inference output buffer ptr (_inputPtr -> _patchInputPtr -> _patchOutputPtr -> _outputPtr)
    float* _patchInputPtr = nullptr; // patches output buffer ptr (_inputPtr --patch division--> _patchInputPtr)
    float* _patchOutputPtr = nullptr; // patches output buffer ptr (_patchInputPtr --patch inference--> _patchOutputPtr)
    int* _outputPixelCount = nullptr;
    std::vector<int> _inputShape;
    std::vector<char*> _patchInputPtrList;
    std::vector<char*> _patchOutputPtrList;
    std::vector<int> _scores;
    PatchConfig _config;
    bool flag = false; // whether generate patch or not
};

#endif
