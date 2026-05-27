import { getJSON } from "./devClient";

export const infoAPI = {
  info: () => getJSON<{
    port: number;
    home: string;
    forgifyHome: string;
    testendDir: string;
    mcpConfigPath: string;
    skillsDir: string;
    catalogCachePath: string;
    buildID?: string;
    goVersion?: string;
    startedAt?: string;
    tableCounts?: Record<string, number>;
  }>("/dev/info"),
  runtime: () => getJSON<{
    uptimeSec: number;
    numGoroutine: number;
    memAllocBytes: number;
    memSysBytes: number;
    numGC: number;
    dbSizeBytes?: number;
  }>("/dev/runtime"),
  forgifyHome: () => getJSON<{
    path: string;
    mcpJson?: string;
    skillsDir?: string;
    catalogJson?: string;
    tree?: Array<{ name: string; size: number; isDir: boolean; modified: string }>;
  }>("/dev/forgify-home"),
  bashProcesses: () => getJSON<{
    processes: Array<{
      id: string;
      command: string;
      cwd: string;
      startedAt: string;
      status: string;
      exitCode?: number;
    }>;
  }>("/dev/bash-processes"),
};
