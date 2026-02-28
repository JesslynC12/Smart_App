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

    const { userId, name, nik, lokasi, role, privilegeIds } = body;

    if (!userId) throw new Error("UserId wajib disertakan");

    // 1. Update Auth (Metadata Nama)
    const { error: authError } = await supabaseAdmin.auth.admin.updateUserById(userId, {
      user_metadata: { name: name }
    })
    if (authError) throw authError

    // 2. Update Tabel Profiles
    const { error: profileError } = await supabaseAdmin
      .from('profiles')
      .update({ 
        name, 
        nik, 
        lokasi, 
        role 
      })
      .eq('id', userId)

    if (profileError) throw profileError

    // 3. Update Hak Akses (Delete lalu Insert Baru)
    // PERBAIKAN: Gunakan 'profile_id' sesuai skema database Anda
    await supabaseAdmin.from('profile_privileges').delete().eq('profile_id', userId)

    if (privilegeIds && Array.isArray(privilegeIds) && privilegeIds.length > 0) {
      const privData = privilegeIds.map((pId: number) => ({
        profile_id: userId, // PERBAIKAN: profile_id
        privilege_id: pId
      }))
      
      const { error: privError } = await supabaseAdmin
        .from('profile_privileges')
        .insert(privData)
        
      if (privError) throw privError
    }

    return new Response(JSON.stringify({ message: "User updated successfully" }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })

  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})