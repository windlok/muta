import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );
  try {
    const token = req.headers.get('Authorization')?.replace('Bearer ', '');
    const { data: auth } = await supabase.auth.getUser(token);
    if (!auth.user) {
      return Response.json(
        { error: 'Oturum gerekli' },
        { status: 401, headers: cors },
      );
    }
    const body = await req.json();
    const query = String(body?.query ?? '').trim();
    const platforms = Array.isArray(body?.platforms) ? body.platforms : [];
    if (!query) {
      return Response.json(
        { error: 'query gerekli' },
        { status: 400, headers: cors },
      );
    }
    const { data: search, error } = await supabase
      .from('product_searches')
      .insert({ user_id: auth.user.id, query, platforms, status: 'queued' })
      .select()
      .single();
    if (error) throw error;

    const githubToken = Deno.env.get('GITHUB_ACTIONS_TOKEN');
    const repository = Deno.env.get('GITHUB_WORKER_REPOSITORY');
    if (!githubToken || !repository) {
      return Response.json(
        { search_id: search.id, status: 'queued', results: [] },
        { headers: cors },
      );
    }

    const dispatch = await fetch(
      `https://api.github.com/repos/${repository}/dispatches`,
      {
        method: 'POST',
        headers: {
          Accept: 'application/vnd.github+json',
          Authorization: `Bearer ${githubToken}`,
          'X-GitHub-Api-Version': '2022-11-28',
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          event_type: 'product-search',
          client_payload: { search_id: search.id, query, platforms },
        }),
      },
    );
    if (!dispatch.ok) {
      throw new Error(`GitHub dispatch failed: ${dispatch.status}`);
    }
    return Response.json(
      { search_id: search.id, status: 'queued', results: [] },
      { headers: cors },
    );
  } catch (error) {
    return Response.json(
      { error: error instanceof Error ? error.message : String(error) },
      { status: 500, headers: cors },
    );
  }
});
