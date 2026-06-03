package stream

// Node is one member of a stream's semantic vocabulary — a discriminated-union
// payload. NodeType is the on-wire "type" discriminant; concrete nodes live in each
// stream's domain package (messages / entities / notifications). Because Node is an
// interface, a node defined for one stream can be carried on another with no import
// between the stream packages — this is what makes dual-output free.
//
// Node 是某条流语义词表的一个成员——判别联合 payload。NodeType 是线缆上的 "type"
// 判别字段；具体 node 定义在各流 domain 包。因为 Node 是 interface，某条流定义的 node
// 可被另一条流携带、流包之间无需 import——这正是双输出免费的根由。
type Node interface {
	NodeType() string
}
