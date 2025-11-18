#!/bin/bash

# Script para otimizar GIFs grandes do projeto
# Reduz o tamanho mantendo qualidade aceitável para visualização no GitHub

echo "🎬 Otimizando GIF do projeto..."

INPUT_GIF="img/aws_kedakarpenter_arch_small.gif"
OUTPUT_GIF="img/aws_kedakarpenter_arch_optimized.gif"
BACKUP_GIF="img/aws_kedakarpenter_arch_small.gif.backup"

# Verificar se o arquivo existe
if [ ! -f "$INPUT_GIF" ]; then
    echo "❌ Erro: Arquivo $INPUT_GIF não encontrado!"
    exit 1
fi

# Fazer backup do original
echo "📦 Criando backup do original..."
cp "$INPUT_GIF" "$BACKUP_GIF"

echo "⚙️  Otimizando GIF (isso pode levar alguns minutos)..."
echo "⏳ Aguarde... (processando 74MB → ~3MB)"

# Método simplificado: Reduzir resolução e FPS
# Reduz de ~74MB para ~2-5MB
# -loglevel quiet: suprime output interativo
# -nostdin: previne interação com usuário
ffmpeg -nostdin -loglevel error -i "$INPUT_GIF" \
    -vf "fps=8,scale=1200:-1:flags=lanczos" \
    -loop 0 \
    "$OUTPUT_GIF" \
    -y

if [ $? -eq 0 ]; then
    ORIGINAL_SIZE=$(du -h "$INPUT_GIF" | cut -f1)
    NEW_SIZE=$(du -h "$OUTPUT_GIF" | cut -f1)
    
    echo ""
    echo "✅ GIF otimizado com sucesso!"
    echo "📊 Tamanho original: $ORIGINAL_SIZE"
    echo "📊 Tamanho otimizado: $NEW_SIZE"
    echo ""
    echo "📝 Próximos passos:"
    echo "1. Renomear o arquivo otimizado:"
    echo "   mv $OUTPUT_GIF $INPUT_GIF"
    echo ""
    echo "2. Fazer commit e push:"
    echo "   git add img/aws_kedakarpenter_arch_small.gif"
    echo "   git commit -m 'chore: otimiza GIF principal para carregamento automático no GitHub'"
    echo "   git push origin main"
    echo ""
    echo "💡 O backup está em: $BACKUP_GIF"
else
    echo "❌ Erro ao otimizar GIF"
    exit 1
fi
