import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const body = await req.json().catch(() => null);
    if (!body) throw new Error("Request body kosong");

    const { email, password, nik, name, lokasi, role, privilegeIds } = body;

    // 1. Cek NIK Duplikat
    const { data: existingNik } = await supabaseAdmin
      .from('profiles')
      .select('nik')
      .eq('nik', nik)
      .maybeSingle()

    if (existingNik) {
      return new Response(JSON.stringify({ error: `NIK ${nik} sudah terdaftar!` }), { 
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      })
    }

    // 2. Buat User di Auth
    const { data: authData, error: authError } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { name }
    })

    if (authError) throw authError
    const userId = authData.user.id

    // 3. Simpan Profil
    const { error: profileError } = await supabaseAdmin.from('profiles').insert({
      id: userId,
      nik,
      name,
      email,
      lokasi,
      role,
      is_active: true // Pastikan status aktif saat dibuat
    })

    if (profileError) {
      await supabaseAdmin.auth.admin.deleteUser(userId) 
      throw profileError
    }

    // 4. Simpan Hak Akses (PERBAIKAN DI SINI)
    if (privilegeIds && Array.isArray(privilegeIds) && privilegeIds.length > 0) {
      // Sesuaikan nama kolom dengan tabel: profile_id
      const privData = privilegeIds.map((pId: number) => ({ 
        profile_id: userId, 
        privilege_id: pId 
      }))

      const { error: privError } = await supabaseAdmin
        .from('profile_privileges')
        .insert(privData)

      if (privError) {
        console.error("Gagal simpan privileges:", privError)
        // Opsional: Anda bisa melempar error di sini jika privilege wajib ada
      }
    }

    return new Response(JSON.stringify({ message: "User internal berhasil dibuat" }), {
      status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })

  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})