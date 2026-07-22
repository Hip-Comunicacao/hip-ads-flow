# HIP Ads Flow

Sistema interno da HIP Comunicação para gestão de campanhas e solicitações de mídia digital.

## Versão

**v1.3.4**

Principais ajustes:

- criação de solicitações dentro de campanhas existentes;
- reaproveitamento dos dados da campanha;
- formulário simplificado para novas solicitações;
- opção preservada para criação de novas campanhas;
- Node.js 20 configurado para o build no Netlify.

## Desenvolvimento local

1. Instale as dependências:

```bash
npm install
```

2. Crie um arquivo `.env.local` com base no `.env.example`.

3. Inicie o projeto:

```bash
npm run dev
```

## Netlify

- Build command: `npm run build`
- Publish directory: `dist`
- Branch de testes recomendada: `develop`
- Branch de produção recomendada: `main`

As variáveis `VITE_SUPABASE_URL` e `VITE_SUPABASE_PUBLISHABLE_KEY` devem ser cadastradas no painel do Netlify.

## Banco de dados

A pasta `supabase/migrations` mantém a atualização necessária para as operações/solicitações introduzidas na base v1.3.3. Em um ambiente que já utiliza a v1.3.3 corretamente, não é necessário executá-la novamente.
