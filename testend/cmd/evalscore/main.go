// evalscore folds evalbench JSONL rows into the Summary that backs the measured claims about
// Anselm (Pass@1 / Pass@3, repair success / regression / false repair). It prints Markdown by
// default and JSON with -json; every ratio carries its numerator and denominator so a reader can
// recompute the number by hand. The ratios are defined in testend/evalbench/score.go, nowhere else.
//
// evalscore 把 evalbench 的 JSONL 行折叠成支撑 Anselm 测量结论的 Summary（Pass@1 / Pass@3、修复成功 /
// 回归 / 误修复）。默认输出 Markdown，-json 输出 JSON；每个比率都带分子分母，读者可手算复核。比率定义
// 只在 testend/evalbench/score.go 一处。
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"

	"github.com/sunweilin/anselm/testend/evalbench"
)

func main() {
	in := flag.String("in", "evalbench/out/results.jsonl", "JSONL written by make -C backend evalbench")
	model := flag.String("model", "", "only rows for this model id (empty = all rows)")
	asJSON := flag.Bool("json", false, "print the Summary as JSON instead of Markdown")
	flag.Parse()

	f, err := os.Open(*in)
	if err != nil {
		fmt.Fprintln(os.Stderr, "evalscore:", err)
		os.Exit(2)
	}
	defer f.Close()
	builds, repairs, err := evalbench.ReadRows(f)
	if err != nil {
		fmt.Fprintln(os.Stderr, "evalscore:", err)
		os.Exit(2)
	}
	s := evalbench.Score(*model, builds, repairs)
	if *asJSON {
		enc := json.NewEncoder(os.Stdout)
		enc.SetIndent("", "  ")
		_ = enc.Encode(s)
		return
	}
	fmt.Print(evalbench.Markdown(s))
}
