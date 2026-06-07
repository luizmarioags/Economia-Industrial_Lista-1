"""
Configuração central do pacote Python de replicação do sistema AIDS.

A estrutura replica o fluxo dos scripts R enviados pelo usuário:
    data/raw/meatdata.csv
    data/processed/
    output/tables/
    output/figures/PDF/
    output/figures/PNG/
    output/models/
    output/logs/

Por padrão, os arquivos exportados pelo Python usam sufixo _PY para não
sobrescrever os resultados _R. Se você quiser gerar nomes idênticos aos do R,
troque output_tag="R" ao criar AIDSConfig.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable


@dataclass(slots=True)
class AIDSConfig:
    root: Path = field(default_factory=lambda: Path.cwd())
    output_tag: str = "PY"
    goods: tuple[str, ...] = ("bfvl", "pork", "poult", "fish")
    est_goods: tuple[str, ...] = ("bfvl", "pork", "fish")
    omit_good: str = "poult"

    def __post_init__(self) -> None:
        self.root = Path(self.root).resolve()
        self.output_tag = str(self.output_tag).strip() or "PY"

    @property
    def raw(self) -> Path:
        return self.root / "data" / "raw"

    @property
    def proc(self) -> Path:
        return self.root / "data" / "processed"

    @property
    def out(self) -> Path:
        return self.root / "output"

    @property
    def tables(self) -> Path:
        return self.out / "tables"

    @property
    def figures(self) -> Path:
        return self.out / "figures"

    @property
    def figures_pdf(self) -> Path:
        return self.figures / "PDF"

    @property
    def figures_png(self) -> Path:
        return self.figures / "PNG"

    @property
    def logs(self) -> Path:
        return self.out / "logs"

    @property
    def models(self) -> Path:
        return self.out / "models"

    @property
    def raw_csv(self) -> Path:
        return self.raw / "meatdata.csv"

    @property
    def proc_csv(self) -> Path:
        return self.proc / self.tagged("meatdata_aids_preparado", ext="csv")

    @property
    def proc_pickle(self) -> Path:
        return self.proc / self.tagged("meatdata_aids_preparado", ext="pkl")

    def tagged(self, stem: str, ext: str = "csv") -> str:
        """Retorna nome com sufixo do ambiente, por exemplo coeficientes_PY.csv."""
        ext = ext.lstrip(".")
        return f"{stem}_{self.output_tag}.{ext}"

    def tagged_table(self, stem: str, ext: str = "csv") -> Path:
        return self.tables / self.tagged(stem, ext)

    def tagged_model(self, stem: str, ext: str = "pkl") -> Path:
        return self.models / self.tagged(stem, ext)

    def ensure_dirs(self) -> None:
        for path in [
            self.proc,
            self.tables,
            self.figures,
            self.figures_pdf,
            self.figures_png,
            self.logs,
            self.models,
        ]:
            path.mkdir(parents=True, exist_ok=True)


def find_project_root(start: str | Path | None = None) -> Path:
    """Localiza a raiz do pacote, procurando data/raw/meatdata.csv na pasta atual ou nas pastas superiores."""
    base = Path.cwd() if start is None else Path(start)
    base = base.resolve()
    candidates = [base, *base.parents]
    for cand in candidates:
        if (cand / "data" / "raw" / "meatdata.csv").exists():
            return cand
    return base


def default_config(root: str | Path | None = None, output_tag: str = "PY") -> AIDSConfig:
    return AIDSConfig(root=find_project_root(root), output_tag=output_tag)


def required_columns_for_goods(goods: Iterable[str]) -> list[str]:
    cols: list[str] = []
    for g in goods:
        cols.extend([f"{g}p", f"{g}q"])
    return cols
