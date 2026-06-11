package orm

import "testing"

func TestParseMeta_Roles(t *testing.T) {
	m := metaOf[widget]()

	if m.pk == nil || m.pk.name != "id" {
		t.Fatalf("pk = %+v, want id", m.pk)
	}
	if m.ws == nil || m.ws.name != "workspace_id" {
		t.Errorf("ws = %+v, want workspace_id", m.ws)
	}
	if m.created == nil || m.created.name != "created_at" {
		t.Errorf("created = %+v", m.created)
	}
	if m.updated == nil || m.updated.name != "updated_at" {
		t.Errorf("updated = %+v", m.updated)
	}
	if m.deleted == nil || m.deleted.name != "deleted_at" {
		t.Errorf("deleted = %+v", m.deleted)
	}

	var tags *column
	for i := range m.cols {
		if m.cols[i].name == "tags" {
			tags = &m.cols[i]
		}
	}
	if tags == nil || !tags.json {
		t.Errorf("tags column missing json flag: %+v", tags)
	}
	if got := len(m.columnNames()); got != 8 {
		t.Errorf("columnNames count = %d, want 8 (%v)", got, m.columnNames())
	}
}

func TestParseMeta_PanicsWithoutPK(t *testing.T) {
	defer func() {
		if recover() == nil {
			t.Error("expected panic for a struct with no pk column")
		}
	}()
	type noPK struct {
		Name string `db:"name"`
	}
	metaOf[noPK]()
}

func TestParseMeta_PanicsOnUnknownOption(t *testing.T) {
	defer func() {
		if recover() == nil {
			t.Error("expected panic for an unknown db tag option")
		}
	}()
	type bad struct {
		ID string `db:"id,pk,bogus"`
	}
	metaOf[bad]()
}
