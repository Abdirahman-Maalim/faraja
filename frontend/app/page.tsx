import { ProjectForm } from "@/components/project-form";
import { listProjects } from "@/lib/api";

function statusLabel(status: string): string {
  return status.replaceAll("_", " ");
}

export default async function HomePage() {
  const projects = await listProjects();

  const totalAllocated = projects.reduce(
    (sum, project) => sum + project.budget_allocated,
    0
  );
  const totalSpent = projects.reduce(
    (sum, project) => sum + project.budget_spent,
    0
  );

  return (
    <main>
      <section className="header">
        <h1 style={{ marginTop: 0, marginBottom: 8 }}>Faraja Public Tracker · CI/CD live</h1>
        <p style={{ margin: 0, maxWidth: 700 }}>
          A transparency dashboard to track government project delivery, spending,
          and implementation progress for citizen accountability.
        </p>
      </section>

      <section className="grid two" style={{ marginBottom: 16 }}>
        <article className="card">
          <p className="small">Total Projects</p>
          <h2 style={{ marginTop: 6 }}>{projects.length}</h2>
        </article>
        <article className="card">
          <p className="small">Budget Oversight</p>
          <h2 style={{ marginTop: 6 }}>
            {totalSpent.toLocaleString()} / {totalAllocated.toLocaleString()}
          </h2>
        </article>
      </section>

      <section className="grid two">
        <article className="card">
          <h3 style={{ marginTop: 0 }}>Add Government Project</h3>
          <ProjectForm />
        </article>

        <article className="card" style={{ overflowX: "auto" }}>
          <h3 style={{ marginTop: 0 }}>Projects</h3>
          <table className="table">
            <thead>
              <tr>
                <th>Name</th>
                <th>County</th>
                <th>Status</th>
                <th>Budget</th>
                <th>Spent</th>
              </tr>
            </thead>
            <tbody>
              {projects.map((project) => (
                <tr key={project.id}>
                  <td>{project.name}</td>
                  <td>{project.county}</td>
                  <td>
                    <span className="badge">{statusLabel(project.status)}</span>
                  </td>
                  <td>{project.budget_allocated.toLocaleString()}</td>
                  <td>{project.budget_spent.toLocaleString()}</td>
                </tr>
              ))}
              {projects.length === 0 && (
                <tr>
                  <td colSpan={5} className="small">
                    No projects yet.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </article>
      </section>
    </main>
  );
}
