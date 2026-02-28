import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // 1. Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const body = await req.json().catch(() => null);
    if (!body || !body.userId) {
      return new Response(JSON.stringify({ error: "userId diperlukan" }), { 
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      });
    }

    const { userId } = body;

    // 2. Proteksi: Mencegah Admin menghapus dirinya sendiri (Opsional tapi disarankan)
    // Anda bisa mengirimkan ID admin yang sedang login via header jika perlu pengecekan ini.

    // 3. Eksekusi Penghapusan di Auth
    // Karena tabel 'profiles', 'vendor_details', dan 'profile_privileges' menggunakan 
    // 'on delete CASCADE' merujuk ke auth.users(id), maka semua data terkait akan ikut terhapus otomatis.
    const { error } = await supabaseAdmin.auth.admin.deleteUser(userId)
    
    if (error) {
      // Jika user tidak ditemukan, tetap kembalikan error yang jelas
      throw error
    }

    return new Response(JSON.stringify({ message: "User dan data terkait berhasil dihapus permanen" }), {
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