import { API_BASE_URL } from "./auth";

export type ProjectRecord = {
  project_id?: string;
  id?: string;
  name?: string;
  description?: string;
  industry_type?: string;
  current_role?: string;
  created_at?: string;
  [key: string]: unknown;
};

const PROJECTS_LIST_PATH = "/0.1.0/projects";

export const resolveProjectId = (project: ProjectRecord): string =>
  String(project.project_id ?? project.id ?? "");

export const normalizeProjectsList = (payload: unknown): ProjectRecord[] => {
  if (Array.isArray(payload)) return payload as ProjectRecord[];
  if (payload && typeof payload === "object") {
    const obj = payload as Record<string, unknown>;
    if (Array.isArray(obj.projects)) return obj.projects as ProjectRecord[];
    if (Array.isArray(obj.items)) return obj.items as ProjectRecord[];
    if (Array.isArray(obj.data)) return obj.data as ProjectRecord[];
  }
  return [];
};

export const fetchProjects = async (token: string): Promise<ProjectRecord[]> => {
  const response = await fetch(`${API_BASE_URL}${PROJECTS_LIST_PATH}`, {
    method: "GET",
    headers: {
      Authorization: `Bearer ${token}`,
    },
    cache: "no-store",
  });

  const data = (await response.json().catch(() => ({}))) as Record<string, unknown>;

  if (!response.ok) {
    const detail = data.detail ?? data.message ?? data.error;
    const message =
      typeof detail === "string"
        ? detail
        : `Failed to load projects (status ${response.status})`;
    throw new Error(message);
  }

  return normalizeProjectsList(data);
};
