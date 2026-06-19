package attachment

import (
	"context"
	"fmt"

	catalogdomain "github.com/sunweilin/anselm/backend/internal/domain/catalog"
)

// AsCatalogSource returns the CatalogSource adapter for this Service: it reports every live
// attachment as a name+description item so the LLM is aware uploaded files exist (and can pull
// one back via read_attachment).
//
// AsCatalogSource 返本 Service 的 CatalogSource 适配器：把每个活跃附件报成 name+description 条目，
// 让 LLM 知道上传文件存在（并可经 read_attachment 拉回）。
func (s *Service) AsCatalogSource() catalogdomain.CatalogSource {
	return &attachmentCatalogSource{svc: s}
}

type attachmentCatalogSource struct{ svc *Service }

var _ catalogdomain.CatalogSource = (*attachmentCatalogSource)(nil)

func (c *attachmentCatalogSource) Name() string { return "attachment" }

// ListItems flattens every live attachment into a catalog Item: Name = filename, Description =
// kind + mime + size so the LLM sees at a glance what each file is before deciding to read it.
//
// ListItems 把所有活跃附件摊平成 catalog Item：Name 用 filename，Description 用 kind + mime + size，
// 让 LLM 一眼看出每个文件是什么、再决定是否读。
func (c *attachmentCatalogSource) ListItems(ctx context.Context) ([]catalogdomain.Item, error) {
	rows, err := c.svc.List(ctx)
	if err != nil {
		return nil, err
	}
	items := make([]catalogdomain.Item, 0, len(rows))
	for _, a := range rows {
		items = append(items, catalogdomain.Item{
			Source:      "attachment",
			ID:          a.ID,
			Name:        a.Filename,
			Description: fmt.Sprintf("%s, %s, %d bytes", a.Kind, a.MimeType, a.SizeBytes),
		})
	}
	return items, nil
}
