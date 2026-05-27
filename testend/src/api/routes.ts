import { getJSON } from "./devClient";

export interface Route {
  method: string;
  path: string;
}

export const routesAPI = {
  list: () => getJSON<Route[]>("/dev/routes"),
};
