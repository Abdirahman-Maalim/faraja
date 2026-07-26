import { CreateProjectPayload, Project } from "@/lib/types";

const API_BASE_URL =
  (globalThis as any).process?.env?.NEXT_PUBLIC_API_BASE_URL ?? "http://127.0.0.1:8000";
export async function listProjects(): Promise<Project[]> {
  try {
    const response = await fetch(`${API_BASE_URL}/projects`, {
      cache: "no-store"
    });

    if (!response.ok) {
      return [];
    }

    return response.json();
  } catch {
    return [];
  }
}

export async function createProject(payload: CreateProjectPayload): Promise<Project> {
  try {
    const response = await fetch(`${API_BASE_URL}/projects`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify(payload)
    });

    if (!response.ok) {
      throw new Error("Failed to create project");
    }

    return response.json();
  } catch {
    throw new Error(
      `Cannot reach backend API at ${API_BASE_URL}. Ensure FastAPI is running.`
    );
  }
}
