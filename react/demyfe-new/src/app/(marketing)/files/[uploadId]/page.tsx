import { FileDetailScreen } from "@/modules/library/screens/file-detail-screen";

export default async function FileDetailPage({
  params,
}: {
  params: Promise<{ uploadId: string }>;
}) {
  const { uploadId } = await params;
  return <FileDetailScreen uploadId={uploadId} />;
}
