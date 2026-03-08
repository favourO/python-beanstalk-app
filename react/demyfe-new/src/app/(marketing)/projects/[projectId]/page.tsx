import { ProjectDetailScreen } from "@/modules/projects/screens/project-detail-screen";

type ProjectDetailPageProps = {
  params: Promise<{ projectId: string }>;
};

export default async function ProjectDetailPage({ params }: ProjectDetailPageProps) {
  const { projectId } = await params;

  return <ProjectDetailScreen projectId={projectId} />;
}
