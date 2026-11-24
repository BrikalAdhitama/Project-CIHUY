// CIHUY: hapus akun milik pemanggil beserta datanya.
//
// Klien tidak boleh menghapus user auth sendiri (hanya memiliki publishable
// key), sehingga penghapusan dilakukan di sini memakai service role. Identitas
// selalu diambil dari token yang sudah diverifikasi, bukan dari body request.
//
// Deploy: supabase functions deploy delete-account
// Rahasia tidak perlu diisi manual; SUPABASE_URL/ANON/SERVICE_ROLE sudah
// tersedia otomatis pada runtime Edge Functions.

import { createClient } from 'npm:@supabase/supabase-js@2';

const avatarBucket = 'photo-profil';

function json(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method !== 'POST') {
    return json(405, { error: 'method_not_allowed' });
  }

  const authorization = request.headers.get('Authorization');
  if (authorization === null || !authorization.startsWith('Bearer ')) {
    return json(401, { error: 'unauthorized' });
  }

  const url = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY') ??
    Deno.env.get('SUPABASE_PUBLISHABLE_KEY');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ??
    Deno.env.get('SUPABASE_SECRET_KEY');
  if (!url || !anonKey || !serviceKey) {
    return json(500, { error: 'server_misconfigured' });
  }

  const caller = createClient(url, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: authData, error: authError } = await caller.auth.getUser();
  if (authError !== null || !authData?.user) {
    return json(401, { error: 'unauthorized' });
  }
  const userId = authData.user.id;

  const admin = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // Foto profil disimpan di Storage dan TIDAK ikut terhapus lewat cascade
  // auth.users, jadi harus dibersihkan lebih dulu.
  const { data: files, error: listError } = await admin.storage
    .from(avatarBucket)
    .list(userId, { limit: 1000 });
  if (listError !== null) {
    return json(500, { error: 'storage_list_failed' });
  }
  if (files !== null && files.length > 0) {
    const { error: removeError } = await admin.storage
      .from(avatarBucket)
      .remove(files.map((file) => `${userId}/${file.name}`));
    if (removeError !== null) {
      return json(500, { error: 'storage_delete_failed' });
    }
  }

  // profiles.id mereferensikan auth.users dengan ON DELETE CASCADE, dan
  // seluruh tabel catatan/preferensi/perangkat mengikuti profiles, sehingga
  // satu penghapusan user menghapus semua baris miliknya.
  const { error: deleteError } = await admin.auth.admin.deleteUser(userId);
  if (deleteError !== null) {
    return json(500, { error: 'delete_failed' });
  }

  return json(200, { deleted: true });
});
