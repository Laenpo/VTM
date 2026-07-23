//
//  VTM-Bridging-Header.h
//  VTM
//
//  Objective-C 桥接头 — 暴露 ONNX Runtime ObjC 类型给 Swift
//

// ORT 枚举类型 (ORTLoggingLevel, ORTTensorElementDataType, ORTGraphOptimizationLevel 等)
#import "ort_enums.h"

// ORT 环境
#import "ort_env.h"

// ORT 会话 & 配置
#import "ort_session.h"

// ORT 张量值
#import "ort_value.h"
