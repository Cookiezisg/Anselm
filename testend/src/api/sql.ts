import { postJSON } from "./devClient";

export interface SqlResult {
  columns: string[];
  rows: unknown[][];
}

export const sqlAPI = {
  run: (sql: string) => postJSON<SqlResult>("/dev/sql", { sql }),
};
