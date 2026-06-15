package handler

import schemapkg "github.com/sunweilin/foryx/backend/internal/pkg/schema"

// MethodSpec is one Python method's full description (I/O schema + body).
//
// MethodSpec 是一个 Python method 的完整描述（I/O schema + body）。
type MethodSpec struct {
	Name        string            `json:"name"`
	Description string            `json:"description,omitempty"`
	Inputs      []schemapkg.Field `json:"inputs"`
	Outputs     []schemapkg.Field `json:"outputs,omitempty"`

	// Body is the Python method body without the def header.
	// Body 是 method body 字符串，不含 def 头。
	Body string `json:"body"`

	// Streaming=true means the body yields; the driver turns each yield into a progress delta.
	// Streaming=true 表 body 用 yield；driver 把每次 yield 翻成 progress delta。
	Streaming bool `json:"streaming"`

	// Timeout in ms: a deadline the app layer puts on each call of THIS method (0 = none —
	// only the caller's own ctx bounds it). Guards the resident instance's serial stdio pipe
	// from a wedged method.
	// 单 method timeout（ms）：app 层给该 method 每次调用加 deadline（0 = 不加——只受调用方自身
	// ctx 约束）。防卡死的 method 堵住常驻实例的串行 stdio 管道。
	Timeout int `json:"timeout,omitempty"`
}

// InitArgSpec describes one __init__ one-time parameter; Sensitive=true → encrypted at rest
// + masked on read. This is the handler's instantiation config (API keys, endpoints), NOT
// method I/O — so it keeps its own typed shape (with Sensitive/Required/Default), not
// schema.Field.
//
// InitArgSpec 是 __init__ 一次性参数的 schema；Sensitive=true → 加密存、读时掩码。这是 handler
// 实例化配置（API key、endpoint），**非** method I/O——故保留自己的类型（带 Sensitive/Required/
// Default），不用 schema.Field。
type InitArgSpec struct {
	Name        string `json:"name"`
	Type        string `json:"type"`
	Description string `json:"description,omitempty"`
	Required    bool   `json:"required"`
	Sensitive   bool   `json:"sensitive"`
	Default     any    `json:"default,omitempty"`
}
