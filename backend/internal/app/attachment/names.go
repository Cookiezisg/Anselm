// NamesByIDs implements the touchpoint Namer port for the attachment kind: id → filename.
// Attachments are not relation-graph nodes, so unlike the entity domains this namer exists
// solely for the conversation ledger's display-name snapshots (an attachment row named
// "report.pdf" beats a bare att_ id in the right island's gallery).
//
// NamesByIDs 实现 touchpoint 的 Namer 端口(attachment 类):id → 文件名。附件不是 relation 图
// 节点,故与实体域不同,此 namer 只为对话台账的显示名快照服务(右岛画廊里 "report.pdf" 远好过
// 裸 att_ id)。
package attachment

import "context"

// NamesByIDs batch-resolves attachment display names (the filename). Missing ids simply get
// no entry — the ledger keeps whatever snapshot it has.
//
// NamesByIDs 批量解析附件显示名(文件名)。缺失 id 无条目——台账保留既有快照。
func (s *Service) NamesByIDs(ctx context.Context, ids []string) (map[string]string, error) {
	rows, err := s.repo.GetBatch(ctx, ids)
	if err != nil {
		return nil, err
	}
	out := make(map[string]string, len(rows))
	for _, a := range rows {
		out[a.ID] = a.Filename
	}
	return out, nil
}
