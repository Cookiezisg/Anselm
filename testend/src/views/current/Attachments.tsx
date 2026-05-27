import { useQuery } from "@tanstack/react-query";
import { useConvStore } from "@/stores/conv";
import { useUIStore } from "@/stores/ui";
import { getJSON } from "@/api/devClient";
import { EmptyView } from "@/ui";

interface Attachment {
  id: string;
  filename: string;
  contentType: string;
  sizeBytes: number;
  extractedExcerpt?: string;
  messageId?: string;
}

function fmtBytes(b: number): string {
  if (b < 1024) return `${b} B`;
  if (b < 1024 ** 2) return `${(b / 1024).toFixed(1)} KB`;
  return `${(b / 1024 ** 2).toFixed(1)} MB`;
}

export function Attachments() {
  const { activeId } = useConvStore();
  const ui = useUIStore();
  const { data, isLoading, isError } = useQuery({
    queryKey: ["attachments", activeId],
    queryFn: () => getJSON<Attachment[]>(`/api/v1/conversations/${activeId}/attachments`),
    enabled: !!activeId,
  });
  if (!activeId) return <EmptyView>pick a conversation</EmptyView>;
  if (isLoading) return <EmptyView>loading…</EmptyView>;
  if (isError || !data || data.length === 0) return <EmptyView>no attachments</EmptyView>;
  return (
    <div style={{ height: "100%", overflow: "auto", padding: 8 }}>
      <table className="dt">
        <thead>
          <tr><th>filename</th><th>contentType</th><th>size</th><th>excerpt</th><th></th></tr>
        </thead>
        <tbody>
          {data.map((a) => (
            <tr key={a.id}>
              <td>{a.filename}</td>
              <td className="mono">{a.contentType}</td>
              <td className="muted">{fmtBytes(a.sizeBytes)}</td>
              <td style={{ maxWidth: 400, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }} className="muted">
                {a.extractedExcerpt ? a.extractedExcerpt.slice(0, 80) : "—"}
              </td>
              <td>
                <button onClick={() => ui.showRaw(a.filename, a)} className="muted" style={{
                  background: "none", border: "1px solid var(--border)",
                  padding: "1px 6px", borderRadius: 3, fontSize: 10, cursor: "pointer",
                }}>raw</button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
