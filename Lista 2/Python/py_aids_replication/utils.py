"""Funções auxiliares compartilhadas entre os módulos do pacote."""

from __future__ import annotations

import pickle
import re
from pathlib import Path
from typing import Any, Iterable, Sequence

import numpy as np
import pandas as pd


PRODUTO_LABELS = {
    "bfvl": "Carne bovina e vitela",
    "pork": "Carne suína",
    "poult": "Frango",
    "fish": "Pescados",
}

MODELO_LABELS = {
    "irrestrito": "Sem restrições teóricas",
    "homogeneidade": "Com homogeneidade",
    "homog_simetria": "Com homogeneidade e simetria",
    "homog_simetria_L1": "Com homogeneidade e simetria",
    "homog_simetria_L2": "Modelo final com duas defasagens",
}

INSTRUMENTO_LABELS = {
    "L1": "Primeira defasagem",
    "L1_L2": "Primeira e segunda defasagens",
}

PARAMETRO_LABELS = {
    "a_bfvl": "Intercepto: carne bovina e vitela",
    "g11": "Preço próprio: carne bovina e vitela",
    "g12": "Substituição entre bovina/vitela e suína",
    "g14": "Substituição entre bovina/vitela e pescados",
    "b_bfvl": "Dispêndio real: carne bovina e vitela",
    "a_pork": "Intercepto: carne suína",
    "g22": "Preço próprio: carne suína",
    "g24": "Substituição entre suína e pescados",
    "b_pork": "Dispêndio real: carne suína",
    "a_fish": "Intercepto: pescados",
    "g44": "Preço próprio: pescados",
    "b_fish": "Dispêndio real: pescados",
}

AIDS_COLORS = {
    "Carne bovina e vitela": "navy",
    "Carne suína": "#B03060",
    "Frango": "forestgreen",
    "Pescados": "orange",
    "Índice de Stone": "navy",
    "Dispêndio real com carnes": "#B03060",
    "Primeira defasagem": "navy",
    "Primeira e segunda defasagens": "#B03060",
}

GOOD_COLORS = {
    "bfvl": "navy",
    "pork": "#B03060",
    "poult": "forestgreen",
    "fish": "orange",
}


def nome_produto(x: str | Sequence[str]) -> str | list[str]:
    if isinstance(x, str):
        return PRODUTO_LABELS.get(x, x)
    return [PRODUTO_LABELS.get(str(v), str(v)) for v in x]


def nome_modelo(x: str | Sequence[str]) -> str | list[str]:
    if isinstance(x, str):
        return MODELO_LABELS.get(x, x)
    return [MODELO_LABELS.get(str(v), str(v)) for v in x]


def nome_instrumento(x: str | Sequence[str]) -> str | list[str]:
    if isinstance(x, str):
        return INSTRUMENTO_LABELS.get(x, x)
    return [INSTRUMENTO_LABELS.get(str(v), str(v)) for v in x]


def nome_parametro(x: str | Sequence[str]) -> str | list[str]:
    if isinstance(x, str):
        return PARAMETRO_LABELS.get(x, x)
    return [PARAMETRO_LABELS.get(str(v), str(v)) for v in x]


def rotulo_variavel_produto(x: str | Sequence[str]) -> str | list[str]:
    def one(v: str) -> str:
        key = re.sub(r"^L1_lngp_", "", v)
        key = re.sub(r"^lngp_", "", key)
        key = re.sub(r"^w_", "", key)
        key = re.sub(r"p$", "", key)
        return PRODUTO_LABELS.get(key, key)

    if isinstance(x, str):
        return one(x)
    return [one(str(v)) for v in x]


def write_csv(df: pd.DataFrame, path: str | Path) -> None:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(path, index=False)


def read_csv(path: str | Path) -> pd.DataFrame:
    return pd.read_csv(path)


def read_csv_if_exists(path: str | Path) -> pd.DataFrame | None:
    path = Path(path)
    if not path.exists() or str(path) == "None":
        return None
    return pd.read_csv(path)


def save_pickle(obj: Any, path: str | Path) -> None:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("wb") as f:
        pickle.dump(obj, f)


def load_pickle(path: str | Path) -> Any:
    with Path(path).open("rb") as f:
        return pickle.load(f)


def matrix_rank(A: np.ndarray, tol: float = 1e-10) -> int:
    return int(np.linalg.matrix_rank(np.asarray(A, dtype=float), tol=tol))


def safe_solve(A: np.ndarray, tol: float = 1e-10, ridge: float = 1e-8) -> np.ndarray:
    """
    Inversa robusta, espelhando a ideia do safe_solve em R:
    1. tenta solve direto;
    2. tenta solve com ridge proporcional à escala;
    3. usa pseudo-inversa por SVD.
    """
    A = np.asarray(A, dtype=float)
    if A.ndim != 2 or A.shape[0] != A.shape[1]:
        raise ValueError("safe_solve exige matriz quadrada.")

    I = np.eye(A.shape[0])
    try:
        inv = np.linalg.solve(A, I)
        if np.all(np.isfinite(inv)):
            return inv
    except np.linalg.LinAlgError:
        pass

    diag_abs = np.abs(np.diag(A)) if A.size else np.array([0.0])
    escala = np.nanmax(diag_abs) if diag_abs.size else 0.0
    if not np.isfinite(escala) or escala == 0:
        escala = np.nanmax(np.abs(A)) if A.size else 1.0
    if not np.isfinite(escala) or escala == 0:
        escala = 1.0

    A_ridge = A + np.eye(A.shape[0]) * (ridge * escala)
    try:
        inv = np.linalg.solve(A_ridge, I)
        if np.all(np.isfinite(inv)):
            return inv
    except np.linalg.LinAlgError:
        pass

    return np.linalg.pinv(A, rcond=tol)


def chi2_sf(x: float, df: int | float) -> float:
    try:
        from scipy.stats import chi2

        if df is None or df <= 0 or not np.isfinite(x):
            return np.nan
        return float(chi2.sf(x, df))
    except Exception:
        return np.nan


def f_sf(x: float, dfn: int | float, dfd: int | float) -> float:
    try:
        from scipy.stats import f

        if dfn <= 0 or dfd <= 0 or not np.isfinite(x):
            return np.nan
        return float(f.sf(x, dfn, dfd))
    except Exception:
        return np.nan


def matrix_to_long(M: pd.DataFrame | np.ndarray, value_name: str) -> pd.DataFrame:
    if isinstance(M, np.ndarray):
        df = pd.DataFrame(M)
    else:
        df = M.copy()
    return (
        df.reset_index(names="produto_linha")
        .melt(id_vars="produto_linha", var_name="produto_coluna", value_name=value_name)
    )


def normalize_names(cols: Iterable[str]) -> list[str]:
    out: list[str] = []
    for c in cols:
        x = str(c).lower()
        x = re.sub(r"[^a-z0-9]+", "_", x)
        x = re.sub(r"_+", "_", x)
        x = re.sub(r"^_|_$", "", x)
        out.append(x)
    return out


def standardize_table(df: pd.DataFrame | None) -> pd.DataFrame | None:
    if df is None:
        return None
    out = df.copy()
    out.columns = normalize_names(out.columns)
    return out


def find_existing(paths: Iterable[str | Path]) -> Path | None:
    for p in paths:
        path = Path(p)
        if path.exists():
            return path
    return None


def ensure_columns(df: pd.DataFrame, cols: Sequence[str], context: str = "dataframe") -> None:
    missing = [c for c in cols if c not in df.columns]
    if missing:
        raise KeyError(f"Colunas ausentes em {context}: {missing}")
