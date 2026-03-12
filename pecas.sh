#!/bin/bash

# --- 1. CONFIGURAÇÃO DE AMBIENTE ---
BASE_DIR="$HOME/Oficina_Dados"
PASTA_DB="$BASE_DIR/Banco"
PASTA_PDF="$BASE_DIR/PDFs"
PASTA_ZPL="$BASE_DIR/ZPL_Backups"
mkdir -p "$PASTA_DB" "$PASTA_PDF" "$PASTA_ZPL"

ARQUIVO_DB="$PASTA_DB/historico_revisoes.csv"
ARQUIVO_ESTOQUE="$PASTA_DB/estoque.csv"
ARQUIVO_MAQUINAS="$PASTA_DB/maquinas.csv"

# Largura: 580 (80mm/ISD-12) ou 880 (110mm/Elgin L42)
LARGURA="580" 

# Inicializa arquivos CSV
[ ! -f "$ARQUIVO_DB" ] && echo "DATA;PATRIMONIO;MODELO;PECAS;OBS" > "$ARQUIVO_DB"
[ ! -f "$ARQUIVO_ESTOQUE" ] && echo "CODIGO;DESCRICAO;QTD" > "$ARQUIVO_ESTOQUE"
[ ! -f "$ARQUIVO_MAQUINAS" ] && echo "PATRIMONIO;MODELO;DESCRICAO;UNIDADE" > "$ARQUIVO_MAQUINAS"

# --- FUNÇÃO DE IMPRESSÃO (REDUNDÂNCIA lp0/lp1) ---
imprimir_zpl() {
    CONTEUDO=$1
    if [ -e /dev/usb/lp0 ]; then DEST="/dev/usb/lp0"
    elif [ -e /dev/usb/lp1 ]; then DEST="/dev/usb/lp1"
    else echo "!!! IMPRESSORA NÃO ENCONTRADA !!!"; return 1; fi
    echo -e "$CONTEUDO" > "$DEST"
}

# --- 2. MENU PRINCIPAL ---
while true; do
    clear
    echo "=========================================================="
    echo "       SISTEMA MARQUES v8.0 - GESTÃO TOTAL (CLOUD)        "
    echo "=========================================================="
    echo "1. BUSCAR HISTÓRICO          8. CONSULTAR ESTOQUE (Tela)"
    echo "2. NOVA REVISÃO (Baixa)      9. IMPRIMIR SALDO (Ticket)"
    echo "3. RELATÓRIO MENSAL (Term.)  10. CADASTRAR MÁQUINA (Frota)"
    echo "4. GERAR RELATÓRIO PDF       11. RELATÓRIO POR UNIDADE"
    echo "5. ETIQUETA PRATELEIRA       12. SAIR E BACKUP (CLOUD)"
    echo "6. ENTRADA DE MATERIAL       13. RESETAR PORTAS USB"
    echo "7. FOLHA DE INVENTÁRIO       14. TERMO DE ENCERRAMENTO"
    echo "----------------------------------------------------------"
    read -p "Escolha (1-14): " OPCAO

    case $OPCAO in
        1) read -p "Patrimônio: " B; grep -i "$B" "$ARQUIVO_DB" | column -s ';' -t; read -p "Enter..." ;;
        
        2) read -p "Nº Patrimônio: " PAT
            MAQ=$(grep -i "^$PAT;" "$ARQUIVO_MAQUINAS")
            if [ -n "$MAQ" ]; then 
                MOD=$(echo "$MAQ" | cut -d';' -f2); DES=$(echo "$MAQ" | cut -d';' -f3); UNI=$(echo "$MAQ" | cut -d';' -f4)
                echo "Máquina: $DES ($MOD) | Setor: $UNI"
            else read -p "Modelo: " MOD; read -p "Descrição: " DES; UNI="N/A"; fi
            read -p "Obs: " OBS
            CUPOM="^XA^PW$LARGURA^LL1000^CI28^FO30,50^CF0,35^FDMAQUINA: $DES^FS^FO30,90^FDMOD: $MOD | PAT: $PAT^FS"
            CUPOM+="^CF0,25^FO30,140^FDDATA: $(date +%d/%m/%Y)^FS^FO30,170^GB$((LARGURA-60)),2,2^FS"
            P_LOG=""; L=210
            while true; do
                read -p "Cód. Peça (Vazio p/ sair): " C_P; [ -z "$C_P" ] && break
                read -p "Qtd: " Q_U; EX=$(grep -i "^$C_P;" "$ARQUIVO_ESTOQUE")
                if [ -n "$EX" ]; then
                    D_E=$(echo "$EX" | cut -d';' -f2); Q_E=$(echo "$EX" | cut -d';' -f3)
                    if [ "$Q_E" -ge "$Q_U" ]; then
                        N_Q=$((Q_E - Q_U)); sed -i "/^$C_P;/d" "$ARQUIVO_ESTOQUE"; echo "$C_P;$D_E;$N_Q" >> "$ARQUIVO_ESTOQUE"
                        CUPOM+="^FO30,$L^FD- $D_E^FS^FO$((LARGURA-120)),$L^FD$Q_U un^FS"
                        [ "$N_Q" -lt 3 ] && { let L=L+30; CUPOM+="^FO30,$L^GB$((LARGURA-60)),35,2^FS^FO40,$((L+5))^CF0,20^FD*REPOR: SALDO $N_Q*^FS"; }
                        P_LOG+="$D_E($Q_U) "; let L=L+45
                    else echo "SALDO INSUFICIENTE!"; fi
                else echo "PEÇA NÃO CADASTRADA!"; fi
            done
            CUPOM+="^XZ"; echo "$(date +%d/%m/%Y);$PAT;$MOD;$P_LOG;$OBS" >> "$ARQUIVO_DB"; imprimir_zpl "$CUPOM"; read -p "OK. Enter..." ;;

        3) read -p "Mês/Ano: " M_R; grep "/$M_R" "$ARQUIVO_DB" | column -s ';' -t; read -p "Enter..." ;;
        4) read -p "Mês/Ano: " M_R; N_PDF="$PASTA_PDF/Rel_${M_R/\//-}.pdf"; T="/tmp/rel.txt"; echo -e "OFICINA - $M_R\n" > "$T"; grep "/$M_R" "$ARQUIVO_DB" | column -s ';' -t >> "$T"; enscript -p - "$T" | ps2pdf - "$N_PDF" && xdg-open "$N_PDF" & ;;
        5) read -p "Peça: " N_P; read -p "Cód: " C_B; ETI="^XA^PW$LARGURA^LL400^FO20,20^GB$((LARGURA-40)),360,4^FS^CF0,50^FO40,110^FD${N_P^^}^FS^CF0,35^FO40,220^FDCOD: $C_B^FS^FO40,270^BY2^BCN,70,Y,N,N^FD${C_B//./}^FS^XZ"; imprimir_zpl "$ETI"; read -p "Enter..." ;;
        6) read -p "Cód: " C_N; read -p "Desc: " D_N; read -p "Qtd: " Q_N; EX=$(grep -i "^$C_N;" "$ARQUIVO_ESTOQUE"); if [ -z "$EX" ]; then echo "$C_N;$D_N;$Q_N" >> "$ARQUIVO_ESTOQUE"; else Q_A=$(echo "$EX" | cut -d';' -f3); T_Q=$((Q_A + Q_N)); sed -i "/^$C_N;/d" "$ARQUIVO_ESTOQUE"; echo "$C_N;$D_N;$T_Q" >> "$ARQUIVO_ESTOQUE"; fi; echo "OK!"; sleep 1 ;;
        7) echo "Folha Inventário..."; LIS="^XA^PW$LARGURA^LL3000^CI28^FO30,50^CF0,45^FDFOLHA INVENTARIO - $(date +%d/%m/%Y)^FS^FO30,110^GB$((LARGURA-60)),3,3^FS"; V_L=170; while IFS=';' read -r C D Q; do [[ "$C" == "CODIGO" ]] && continue; LIS+="^FO30,$V_L^FD$D^FS^FO$((LARGURA-150)),$V_L^FD$Q^FS^FO$((LARGURA-80)),$V_L^FD____^FS"; let V_L=V_L+40; done < "$ARQUIVO_ESTOQUE"; LIS+="^XZ"; imprimir_zpl "$LIS"; read -p "Enter..." ;;
        8) read -p "Busca Peça: " T; grep -i "$T" "$ARQUIVO_ESTOQUE" | column -s ';' -t; read -p "Enter..." ;;
        9) read -p "Busca: " T_I; RES=$(grep -i "$T_I" "$ARQUIVO_ESTOQUE" | head -n 1); if [ -n "$RES" ]; then C_EX=$(echo "$RES" | cut -d';' -f1); D_EX=$(echo "$RES" | cut -d';' -f2); Q_EX=$(echo "$RES" | cut -d';' -f3); TIC="^XA^PW$LARGURA^LL300^CI28^FO30,50^GB$((LARGURA-60)),200,3^FS^CF0,45^FO50,100^FD$D_EX^FS^CF0,35^FO50,175^FDCOD: $C_EX^FS^CF0,50^FO$((LARGURA-200)),170^FDQTD: $Q_EX^FS^XZ"; imprimir_zpl "$TIC"; fi; read -p "Enter..." ;;
        10) read -p "Patrimônio: " C_P; read -p "Modelo Técnico: " C_M; read -p "Descrição: " C_D; read -p "Unidade: " C_U; echo "$C_P;$C_M;$C_D;$C_U" >> "$ARQUIVO_MAQUINAS"; echo "OK!"; sleep 1 ;;
        11) read -p "Unidade: " B_U; grep -i "$B_U" "$ARQUIVO_MAQUINAS" | column -s ';' -t; read -p "Enter..." ;;
        
        12) # SAIR + RSYNC + RCLONE
            echo "Iniciando Backups..."
            P="/media/marques1236/OFICINA_BACKUP"
            [ -d "$P" ] && { rsync -av --delete "$BASE_DIR/" "$P/Backup_Oficina/"; echo "Pendrive: OK"; }
            rclone sync "$BASE_DIR/" gdrive:Pasta_Oficina_Drive && echo "Cloud: OK"
            sleep 2; exit ;;

        13) sudo modprobe -r usblp && sudo modprobe usblp; echo "Portas Resetadas!"; sleep 2 ;;

        14) T_E="^XA^PW$LARGURA^LL1100^CI28^FO20,20^GB$((LARGURA-40)),1050,4^FS^CF0,50^FO50,80^FDTERMO DE ENCERRAMENTO^FS^CF0,30^FO50,200^FDEu, MARQUES1236, declaro encerrado^FS^FO50,240^FDo inventário de ativos e estoque.^FS^FO50,350^FDBACKUP: OK | CLOUD: OK^FS^FO50,500^FDDATA: $(date +%d/%m/%Y)^FS^FO100,800^GB300,2,2^FS^FO120,830^FDMARQUES^FS^FO450,800^GB300,2,2^FS^FO480,830^FDGERENTE^FS^XZ"; imprimir_zpl "$T_E"; read -p "Termo impresso. Parabéns, Mestre! Enter..." ;;
    esac
done

