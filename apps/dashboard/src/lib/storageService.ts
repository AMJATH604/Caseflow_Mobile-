import { supabase } from "@/integrations/supabase/client";

export const R2_SIZE_THRESHOLD_BYTES = 5 * 1024 * 1024; // 5 MB

export interface StorageUploadResult {
  provider: "r2" | "supabase";
  key: string;
  url: string;
}

export type StorageCategory = "legal-documents" | "bare_acts" | "legal_templates";

/**
 * Uploads a file, automatically selecting Cloudflare R2 for large files (>= 5MB)
 * or Bare Acts, and Supabase Storage for small files (< 5MB).
 */
export async function uploadFile(
  file: File,
  category: StorageCategory,
  subPath = ""
): Promise<StorageUploadResult> {
  const isLargeFile = file.size >= R2_SIZE_THRESHOLD_BYTES;
  const isBareAct = category === "bare_acts";
  const useR2 = isLargeFile || isBareAct;

  const timestamp = Date.now();
  const sanitizedName = file.name.replace(/[^a-zA-Z0-9_.-]/g, "_");
  const storageKey = subPath
    ? `${subPath.replace(/\/$/, "")}/${timestamp}_${sanitizedName}`
    : `${category}/${timestamp}_${sanitizedName}`;

  if (useR2) {
    // Cloudflare R2 has no row-level security, so the r2-storage Edge
    // Function authorizes private objects by requiring them to sit under the
    // uploader's own prefix. Build the key to match, or the upload is
    // rejected. Shared libraries keep their flat category prefix and are
    // gated on the admin role server-side instead.
    const key = await buildR2Key(category, subPath, timestamp, sanitizedName);

    // 1. Get presigned PUT URL from r2-storage Edge Function
    const { data: uploadData, error: fnError } = await supabase.functions.invoke("r2-storage", {
      body: {
        action: "get-upload-url",
        key,
        contentType: file.type || "application/octet-stream",
      },
    });

    if (fnError || !uploadData?.uploadUrl) {
      console.warn("Failed to get R2 presigned URL from Edge Function, falling back to Supabase Storage:", fnError);
      return uploadToSupabase(file, category, key);
    }

    // 2. Upload file directly to Cloudflare R2 using presigned URL
    const uploadResp = await fetch(uploadData.uploadUrl, {
      method: "PUT",
      headers: {
        "Content-Type": file.type || "application/octet-stream",
      },
      body: file,
    });

    if (!uploadResp.ok) {
      throw new Error(`R2 upload failed with status ${uploadResp.status}: ${uploadResp.statusText}`);
    }

    // 3. Obtain initial presigned download URL
    const url = await getFileUrl(key, "r2");

    return {
      provider: "r2",
      key,
      url,
    };
  } else {
    return uploadToSupabase(file, category, storageKey);
  }
}

/** Prefixes holding shared reference content, curated by administrators. */
const SHARED_LIBRARY_CATEGORIES: StorageCategory[] = ["bare_acts", "legal_templates"];

/**
 * Builds the R2 object key for an upload.
 *
 * Private files are namespaced under the signed-in user's id because that
 * prefix is what the r2-storage Edge Function checks — it is the boundary
 * that stops one advocate reading or overwriting another's case documents.
 */
async function buildR2Key(
  category: StorageCategory,
  subPath: string,
  timestamp: number,
  sanitizedName: string
): Promise<string> {
  if (SHARED_LIBRARY_CATEGORIES.includes(category)) {
    return `${category}/${timestamp}_${sanitizedName}`;
  }

  const { data, error } = await supabase.auth.getUser();
  if (error || !data?.user) {
    throw new Error("You must be signed in to upload files.");
  }

  const nested = subPath ? `${subPath.replace(/^\/+|\/+$/g, "")}/` : "";
  return `legal-documents/${data.user.id}/${nested}${timestamp}_${sanitizedName}`;
}

async function uploadToSupabase(
  file: File,
  category: StorageCategory,
  key: string
): Promise<StorageUploadResult> {
  const { error: uploadError } = await supabase.storage
    .from(category)
    .upload(key, file, { upsert: true });

  if (uploadError) {
    throw new Error(`Supabase Storage upload error: ${uploadError.message}`);
  }

  const url = await getFileUrl(key, "supabase", category);
  return {
    provider: "supabase",
    key,
    url,
  };
}

/**
 * Generates a signed or public download URL for a stored file depending on its provider.
 */
export async function getFileUrl(
  key: string,
  provider: "r2" | "supabase" = "supabase",
  bucketName: StorageCategory = "legal-documents"
): Promise<string> {
  if (!key) return "";

  // If key already contains full HTTP/HTTPS URL, return as is
  if (key.startsWith("http://") || key.startsWith("https://")) {
    return key;
  }

  if (provider === "r2" || key.startsWith("r2://")) {
    const cleanKey = key.replace(/^r2:\/\//, "");
    const { data, error } = await supabase.functions.invoke("r2-storage", {
      body: {
        action: "get-download-url",
        key: cleanKey,
      },
    });

    if (error || !data?.downloadUrl) {
      console.error("Failed to generate R2 download URL:", error);
      throw new Error("Unable to retrieve file from R2");
    }

    return data.downloadUrl;
  } else {
    if (bucketName === "legal_templates" || bucketName === "bare_acts") {
      const { data } = supabase.storage.from(bucketName).getPublicUrl(key);
      return data.publicUrl;
    } else {
      const { data, error } = await supabase.storage
        .from(bucketName)
        .createSignedUrl(key, 3600);

      if (error) {
        console.error("Failed to generate Supabase signed URL:", error);
        const { data: pubData } = supabase.storage.from(bucketName).getPublicUrl(key);
        return pubData.publicUrl;
      }
      return data.signedUrl;
    }
  }
}

/**
 * Deletes a stored file from R2 or Supabase Storage.
 */
export async function deleteFile(
  key: string,
  provider: "r2" | "supabase" = "supabase",
  bucketName: StorageCategory = "legal-documents"
): Promise<void> {
  if (!key) return;

  if (provider === "r2" || key.startsWith("r2://")) {
    const cleanKey = key.replace(/^r2:\/\//, "");
    const { error } = await supabase.functions.invoke("r2-storage", {
      body: {
        action: "delete-object",
        key: cleanKey,
      },
    });
    if (error) {
      console.error("Failed to delete object from R2:", error);
    }
  } else {
    const { error } = await supabase.storage.from(bucketName).remove([key]);
    if (error) {
      console.error("Failed to delete object from Supabase Storage:", error);
    }
  }
}
