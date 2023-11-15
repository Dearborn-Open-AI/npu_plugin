//
// Copyright (C) 2023 Intel Corporation.
// SPDX-License-Identifier: Apache 2.0
//

// RUN: vpux-opt --split-input-file --init-compiler="vpu-arch=VPUX37XX compilation-mode=DefaultHW" --adjust-for-vpu %s | FileCheck %s

// CHECK-LABEL: @ConvertNonDepthWiseGroupDeconvToConv
func.func @ConvertNonDepthWiseGroupDeconvToConv(%arg0: tensor<1x32x64x64xf16>) -> tensor<1x32x128x128xf16> {
    %FILTERS = const.Declare tensor<2x16x16x4x4xf16> = dense<1.000000e+00> : tensor<2x16x16x4x4xf16>

    %RESULT = IE.GroupDeconvolutionOp(%arg0, %FILTERS) {dilations = [1, 1], output_padding = [0, 0], pads_begin = [1, 1], pads_end = [1, 1], strides = [2, 2]} : tensor<1x32x64x64xf16>, tensor<2x16x16x4x4xf16> -> tensor<1x32x128x128xf16>
    return %RESULT : tensor<1x32x128x128xf16>

    // CHECK:       [[CST:%.*]] = const.Declare tensor<1x32x128x2xf16> = dense<0.000000e+00> : tensor<1x32x128x2xf32>, [#const.ConvertElemType<f16>]
    // CHECK:       [[CST_0:%.*]] = const.Declare tensor<1x32x128x1xf16> = dense<0.000000e+00> : tensor<1x32x128x1xf32>, [#const.ConvertElemType<f16>]
    // CHECK:       [[CST_1:%.*]] = const.Declare tensor<1x32x2x131xf16> = dense<0.000000e+00> : tensor<1x32x2x131xf32>, [#const.ConvertElemType<f16>]
    // CHECK:       [[CST_2:%.*]] = const.Declare tensor<1x32x1x131xf16> = dense<0.000000e+00> : tensor<1x32x1x131xf32>, [#const.ConvertElemType<f16>]
    // CHECK:       [[CST_3:%.*]] = const.Declare tensor<16x16x4x4xf16> = dense<1.000000e+00> : tensor<2x16x16x4x4xf16>, [#const.Reverse<2 : i64>, #const.ConvertElemType<f16>, #const.Transpose<#map>, #const.Reshape<[32, 16, 4, 4]>, #const.SubView<[16, 0, 0, 0], [16, 16, 4, 4]>]
    // CHECK:       [[CST_4:%.*]] = const.Declare tensor<16x16x4x4xf16> = dense<1.000000e+00> : tensor<2x16x16x4x4xf16>, [#const.Reverse<2 : i64>, #const.ConvertElemType<f16>, #const.Transpose<#map>, #const.Reshape<[32, 16, 4, 4]>, #const.SubView<[0, 0, 0, 0], [16, 16, 4, 4]>]

    // CHECK:       [[UPS:%.*]] = IE.Upsampling(%arg0) {pad = #IE.UpsamplingPad<pads_channel = [0, 0], pads_height = [0, 1], pads_width = [0, 1]>, upsampling_factor = [2, 2, 1]} : tensor<1x32x64x64xf16> -> tensor<1x32x128x128xf16>
    // CHECK:       [[PAD_INPUT_W:%.*]] = IE.Concat([[CST]], [[UPS]], [[CST_0]]) {static_offsets = {{\[\[}}0, 0, 0, 0], [0, 0, 0, 2], [0, 0, 0, 130]]} : tensor<1x32x128x2xf16>, tensor<1x32x128x128xf16>, tensor<1x32x128x1xf16> -> tensor<1x32x128x131xf16>
    // CHECK:       [[PAD_INPUT:%.*]] = IE.Concat([[CST_1]], [[PAD_INPUT_W]], [[CST_2]]) {static_offsets = {{\[\[}}0, 0, 0, 0], [0, 0, 2, 0], [0, 0, 130, 0]]} : tensor<1x32x2x131xf16>, tensor<1x32x128x131xf16>, tensor<1x32x1x131xf16> -> tensor<1x32x131x131xf16>

    // CHECK:       [[SLICE_0:%.*]] = IE.Slice [[PAD_INPUT]] [0, 0, 0, 0] [1, 16, 131, 131] : tensor<1x32x131x131xf16> to tensor<1x16x131x131xf16>
    // CHECK:       [[CONV_0:%.*]] = IE.Convolution([[SLICE_0]], [[CST_4]]) {dilations = [1, 1], pads_begin = [0, 0], pads_end = [0, 0], strides = [1, 1]} : tensor<1x16x131x131xf16>, tensor<16x16x4x4xf16> -> tensor<1x16x128x128xf16>

    // CHECK:       [[SLICE_1:%.*]] = IE.Slice [[PAD_INPUT]] [0, 16, 0, 0] [1, 16, 131, 131] : tensor<1x32x131x131xf16> to tensor<1x16x131x131xf16>
    // CHECK:       [[CONV_1:%.*]] = IE.Convolution([[SLICE_1]], [[CST_3]]) {dilations = [1, 1], pads_begin = [0, 0], pads_end = [0, 0], strides = [1, 1]} : tensor<1x16x131x131xf16>, tensor<16x16x4x4xf16> -> tensor<1x16x128x128xf16>

    // CHECK:       [[CONCAT:%.*]] = IE.Concat([[CONV_0]], [[CONV_1]]) {static_offsets = {{\[\[}}0, 0, 0, 0], [0, 16, 0, 0]]} : tensor<1x16x128x128xf16>, tensor<1x16x128x128xf16> -> tensor<1x32x128x128xf16>

    // CHECK:       return [[CONCAT]]
}