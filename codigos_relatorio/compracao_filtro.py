import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import sys
import os

relatorios = [
    ("relatorio_ref.txt", "Referência"),
    ("relatorio_minha_limpeza.txt", "Filtragem personalizada"),
    # ("relatorio_binarizacao_com_matlab_limpeza.txt", "Limpeza MATLAB"),
    ("relatorio_binarizacao_com_matlab_limpeza_negada.txt",
     "Remoção de componentes pequenos e abertura morfológica"),
    ("relatorio_binarizacao_com_matlab_limpeza_negada_mais_mediana.txt",
     "Limpeza morfológica seguida de filtro de mediana")
]

def carregar_relatorio(caminho):
    """Carrega um relatório .txt com separador whitespace e retorna DataFrame."""
    try:
        df = pd.read_csv(caminho, sep=r'\s+')
        df['IMAGEM'] = df['IMAGEM'].astype(str)
        df = df.sort_values('IMAGEM').reset_index(drop=True)
        return df
    except Exception as e:
        print(f"Erro ao carregar {caminho}: {e}")
        return None

def calcular_diferencas(ref_df, var_df):
    """Calcula diferenças percentuais (variante - referência) / referência * 100."""
    diffs = {}
    for col in ['TEMPO(s)', 'OBJ_ARVORE', 'CANDIDATOS', 'NUM_GRUPOS']:
        if col in ref_df.columns and col in var_df.columns:
            with np.errstate(divide='ignore', invalid='ignore'):
                diff = (var_df[col] - ref_df[col]) / ref_df[col] * 100
                diff = diff.replace([np.inf, -np.inf], np.nan).fillna(0)
            diffs[col] = diff
    return pd.DataFrame(diffs)

def salvar_resumo(ref_nome, var_nome, var_df, diffs_df, output_txt):
    """Adiciona estatísticas de diferenças ao arquivo de resumo."""
    with open(output_txt, 'a') as f:
        f.write(f"\n{'='*60}\n")
        f.write(f"Comparação: {ref_nome} vs {var_nome}\n")  # still shows descriptions
        f.write(f"{'='*60}\n")
        for col in diffs_df.columns:
            media_diff = diffs_df[col].mean()
            std_diff = diffs_df[col].std()
            f.write(f"{col} -> diferença média: {media_diff:.2f}%  (± {std_diff:.2f}%)\n")
        # f.write("\nDiferenças por imagem:\n")
        # f.write(diffs_df.to_string())
        f.write("\n\n")

def plot_comparacao_individual(ref_df, var_df, ref_nome, var_nome, metricas, output_dir):
    """Gráficos comparativos entre referência e uma variante, com alinhamento correto."""
    indices = np.arange(len(ref_df))

    # --- Tempo (gráfico de barras lado a lado) ---
    if 'TEMPO(s)' in metricas:
        fig, ax = plt.subplots(figsize=(12, 5))
        width = 0.35
        ax.bar(indices - width/2, ref_df['TEMPO(s)'], width, label=ref_nome, color='#1f77b4')
        ax.bar(indices + width/2, var_df['TEMPO(s)'], width, label=var_nome, color='#ff7f0e')
        ax.set_ylabel('Tempo (s)')
        ax.set_xlabel('Imagens de teste')
        ax.set_title('Comparação')   # simplified title
        ax.legend()
        ax.grid(axis='y', linestyle='--', alpha=0.5)
        plt.tight_layout()
        plt.savefig(os.path.join(output_dir, f'tempo_{var_nome.replace(" ", "_")}.png'), dpi=150)
        plt.close()

    # --- Candidatos (gráfico de barras lado a lado) ---
    if 'CANDIDATOS' in metricas:
        fig, ax = plt.subplots(figsize=(12, 5))
        width = 0.35
        ax.bar(indices - width/2, ref_df['CANDIDATOS'], width, label=ref_nome, color='#1f77b4')
        ax.bar(indices + width/2, var_df['CANDIDATOS'], width, label=var_nome, color='#ff7f0e')
        ax.set_ylabel('Quantidade de Candidatos')
        ax.set_xlabel('Imagens de teste')
        ax.set_title('Comparação')
        ax.legend()
        ax.grid(axis='y', linestyle='--', alpha=0.5)
        plt.tight_layout()
        plt.savefig(os.path.join(output_dir, f'candidatos_{var_nome.replace(" ", "_")}.png'), dpi=150)
        plt.close()


    if 'OBJ_ARVORE' in metricas:
        fig, ax = plt.subplots(figsize=(12, 5))
        width = 0.35
        ax.set_yscale('log')
        ax.bar(indices - width/2, ref_df['OBJ_ARVORE'], width, label=ref_nome, color='#1f77b4')
        ax.bar(indices + width/2, var_df['OBJ_ARVORE'], width, label=var_nome, color='#ff7f0e')
        ax.set_ylabel('Número de objetos detectados')
        ax.set_xlabel('Imagens de teste')
        ax.set_title('Comparação')
        ax.legend()
        ax.grid(axis='y', linestyle='--', alpha=0.5)
        plt.tight_layout()
        plt.savefig(os.path.join(output_dir, f'objetos_{var_nome.replace(" ", "_")}.png'), dpi=150)
        plt.close()

    if 'NUM_GRUPOS' in metricas:
        fig, ax = plt.subplots(figsize=(12, 5))
        width = 0.35
        ax.bar(indices - width/2, ref_df['CANDIDATOS'], width, label=ref_nome, color='#1f77b4')
        ax.bar(indices + width/2, var_df['CANDIDATOS'], width, label=var_nome, color='#ff7f0e')
        ax.set_ylabel('Número de grupos')
        ax.set_xlabel('Imagens de teste')
        ax.set_title('Comparação')
        ax.legend()
        ax.grid(axis='y', linestyle='--', alpha=0.5)
        plt.tight_layout()
        plt.savefig(os.path.join(output_dir, f'grupos_{var_nome.replace(" ", "_")}.png'), dpi=150)
        plt.close()

    # --- Demais métricas (gráfico de dispersão + médias) ---
    for col in metricas:
        # if col in ('TEMPO(s)', 'CANDIDATOS'):
        #     continue

        mask = ref_df[col].notna() & var_df[col].notna()
        if mask.sum() == 0:
            print(f"  Aviso: sem dados válidos para {col} entre {ref_nome} e {var_nome}")
            continue

        y_ref = ref_df.loc[mask, col].values
        y_var = var_df.loc[mask, col].values
        x_vals = indices[mask]

        fig, ax = plt.subplots(figsize=(10, 5))

        # if col == 'OBJ_ARVORE':
        #     ax.set_yscale('log')
        #     ax.set_ylabel(f'{col} (Escala Logarítmica)', fontsize=10, fontweight='bold')
        # else:
        #     ax.set_ylabel(col, fontsize=10, fontweight='bold')

        ylabel = ''
        if col == 'OBJ_ARVORE':
            ax.set_yscale('log')
            ylabel = f'Número de objetos detectados (Escala Logarítmica)'
        elif col == 'NUM_GRUPOS':
            ylabel = f'Número de grupos'
        elif col == 'CANDIDATOS':
            ylabel = f'Número de candidatos'
        elif col == 'TEMPO(s)':
            ylabel = f'Tempo de execução'
        else:
            ylabel =col
        ax.set_ylabel(ylabel, fontsize=10, fontweight='bold')

        ax.scatter(x_vals, y_ref, color='#6dafdb', alpha=0.5, label=f'Amostras ({ref_nome})', s=30)
        ax.scatter(x_vals, y_var, color='#e09a5e', alpha=0.5, label=f'Amostras ({var_nome})', s=30)

        mean_ref = y_ref.mean()
        mean_var = y_var.mean()

        ax.axhline(mean_ref, color='#1f77b4', linestyle='-', linewidth=2, label=f'Média: {mean_ref:.2f} ({ref_nome})')
        ax.axhline(mean_var, color='#ff7f0e', linestyle='-', linewidth=2, label=f'Média: {mean_var:.2f} ({var_nome})')

        ax.set_title('Comparação')
        ax.set_xlabel('Imagens de teste')
        ax.grid(True, linestyle=':', alpha=0.6)
        ax.legend(loc='upper left', fontsize=9)
        ax.set_xlim(-1, len(ref_df) * 1.02)

        plt.tight_layout()
        plt.savefig(os.path.join(output_dir, f'{col.lower()}_{var_nome.replace(" ", "_")}.png'), dpi=150)
        plt.close()

def plot_comparacao_agregada(ref_df, variantes_dfs, ref_nome, variantes_nomes, metricas, output_dir):
    x = np.arange(len(ref_df))
    n_variantes = len(variantes_dfs)
    n_barras = 1 + n_variantes
    espacamento_entre_barras = 0.01
    largura_grupo = 0.80
    largura_barra = (largura_grupo - (n_barras - 1) * espacamento_entre_barras) / n_barras
    largura_barra = max(largura_barra, 0.03)
    largura_grupo_real = (n_barras * largura_barra + (n_barras - 1) * espacamento_entre_barras)
    offsets = (-largura_grupo_real / 2 + largura_barra / 2 + np.arange(n_barras) * (largura_barra + espacamento_entre_barras))

    cores = ['#e41a1c', '#2ecc71', '#3498db', '#f1c40f', '#e83e8c', '#9b59b6', '#fd7e14', '#1abc9c', '#d35400', '#c0392b', '#16a085', '#34495e', '#8e44ad', '#27ae60', '#2980b9']
    os.makedirs(output_dir, exist_ok=True)

    for col in metricas:
        if col not in ref_df.columns:
            continue

        if col == 'OBJ_ARVORE':
            ax.set_yscale('log')
            ylabel = f'Número de objetos detectados (Escala Logarítmica)'
        elif col == 'NUM_GRUPOS':
            ylabel = f'Número de grupos'
        elif col == 'CANDIDATOS':
            ylabel = f'Número de candidatos'
        elif col == 'TEMPO(s)':
            ylabel = f'Tempo de execução'
        else:
            ylabel =col

        fig, ax = plt.subplots(figsize=(14, 6))

        ax.bar(x + offsets[0], ref_df[col], width=largura_barra, label=ref_nome, color=cores[0], alpha=0.9, edgecolor='black', linewidth=0.3)

        for i, (var_df, nome_var) in enumerate(zip(variantes_dfs, variantes_nomes)):
            if col not in var_df.columns:
                continue
            ax.bar(x + offsets[i + 1], var_df[col], width=largura_barra, label=nome_var, color=cores[(i + 1) % len(cores)], alpha=0.85, edgecolor='black', linewidth=0.3)

        ax.set_xlabel('Imagens de teste')
        ax.set_ylabel(ylabel)
        ax.set_title('Comparação')
        ax.grid(axis='y', linestyle='--', alpha=0.4)
        ax.legend(loc='upper left', fontsize=8, ncol=2)
        plt.tight_layout()
        arquivo_saida = os.path.join(output_dir, f'agregado_{col.lower()}.png')
        plt.savefig(arquivo_saida, dpi=200, bbox_inches='tight')
        plt.close()
        print(f'Gráfico salvo: {arquivo_saida}')

def main():
    flag_all = '--all' in sys.argv
    if flag_all:
        sys.argv.remove('--all')

    arquivos = [r[0] for r in relatorios]
    titulos = [r[1] for r in relatorios]

    if len(arquivos) < 2:
        print("Uso: python compara_relatorios.py [--all] <ref.txt> <var1.txt> [var2.txt ...]")
        print("Ou edite a lista 'relatorios' dentro do script.")
        sys.exit(1)

    # Carrega todos os dataframes, guardando também a descrição
    dados = []
    for arq, titulo in zip(arquivos, titulos):
        df = carregar_relatorio(arq)
        if df is not None:
            dados.append((arq, titulo, df))
        else:
            print(f"Pulando {arq} (falha no carregamento).")

    if len(dados) < 2:
        print("Menos de dois relatórios válidos. Abortando.")
        sys.exit(1)

    ref_arq, ref_nome, ref_df = dados[0]          # ref_nome agora é a descrição
    variantes = [(arq, nome, df) for arq, nome, df in dados[1:]]

    # Alinhamento pelo nome das imagens (se necessário)
    n_imagens_ref = len(ref_df)
    for arq, nome, df in variantes:
        if len(df) != n_imagens_ref:
            print(f"Aviso: {nome} tem {len(df)} imagens, referência tem {n_imagens_ref}. Serão usadas apenas imagens comuns.")
            imagens_ref = set(ref_df['IMAGEM'])
            imagens_comuns = imagens_ref.copy()
            for _, _, df2 in variantes:
                imagens_comuns &= set(df2['IMAGEM'])

            if len(imagens_comuns) < len(imagens_ref):
                print(f"Alinhando dados: {len(imagens_ref)} -> {len(imagens_comuns)} imagens comuns a todos.")
                ref_df = ref_df[ref_df['IMAGEM'].isin(imagens_comuns)].reset_index(drop=True)
                novas_variantes = []
                for arq2, nome2, df2 in variantes:
                    df2 = df2[df2['IMAGEM'].isin(imagens_comuns)].reset_index(drop=True)
                    novas_variantes.append((arq2, nome2, df2))
                variantes = novas_variantes
            else:
                print("Todas as variantes possuem o mesmo conjunto de imagens que a referência.")
            break

    output_dir = "comparison_figures"
    os.makedirs(output_dir, exist_ok=True)

    resumo_txt = os.path.join(output_dir, "comparison_summary.txt")
    with open(resumo_txt, 'w') as f:
        f.write("RESUMO DE COMPARAÇÃO ENTRE RELATÓRIOS\n")
        f.write(f"Referência: {ref_nome}\n")
        f.write(f"Data: {pd.Timestamp.now()}\n\n")

    metricas_disponiveis = ['TEMPO(s)', 'OBJ_ARVORE', 'CANDIDATOS', 'NUM_GRUPOS']

    if flag_all:
        variantes_dfs = [df for _, _, df in variantes]
        variantes_nomes = [nome for _, nome, _ in variantes]
        plot_comparacao_agregada(ref_df, variantes_dfs, ref_nome, variantes_nomes, metricas_disponiveis, output_dir)
        with open(resumo_txt, 'a') as f:
            f.write("\n[ MODO AGREGADO ]\n")
            f.write("Gráficos gerados: cada métrica em uma figura contendo todas as variantes.\n")
    else:
        for arq, var_nome, var_df in variantes:
            common_cols = [c for c in metricas_disponiveis if c in ref_df.columns and c in var_df.columns]
            if not common_cols:
                print(f"Sem métricas comuns entre {ref_nome} e {var_nome}. Pulando.")
                continue

            diffs_df = calcular_diferencas(ref_df, var_df)
            salvar_resumo(ref_nome, var_nome, var_df, diffs_df, resumo_txt)
            plot_comparacao_individual(ref_df, var_df, ref_nome, var_nome, common_cols, output_dir)
            print(f"Gráficos e diferenças salvos para {var_nome}")

    print(f"\nResultados salvos em '{output_dir}/'")
    print(f"Resumo numérico em '{resumo_txt}'")

if __name__ == "__main__":
    main()