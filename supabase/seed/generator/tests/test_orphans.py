from pathlib import Path

import pytest
from generator import orphans, config


@pytest.fixture
def out_path(tmp_path):
    return tmp_path / "02g_orphans.sql"


def test_50_products_total(out_path):
    orphans.write(out_path)
    text = out_path.read_text()
    section = text.split("-- products: ")[1].split("\n\n")[0]
    rows = [ln for ln in section.splitlines() if ln.startswith("  (")]
    assert len(rows) == 50


def test_three_subtypes_present(out_path):
    orphans.write(out_path)
    text = out_path.read_text()
    assert "(DISC)" in text or "DISCONTINUED" in text or "Discontinued" in text
    assert "TEST PRODUCT" in text


def test_all_inactive(out_path):
    orphans.write(out_path)
    text = out_path.read_text()
    section = text.split("-- products: ")[1].split("\n\n")[0]
    n_false = section.count(", FALSE,")
    n_true = section.count(", TRUE,")
    assert n_false >= 50
    assert n_true == 0


def test_skus_unique_and_avoid_smoke(out_path):
    orphans.write(out_path)
    text = out_path.read_text()
    # Smoke uses BB-00001..BB-00010
    section = text.split("-- products: ")[1].split("\n\n")[0]
    for i in range(1, 11):
        forbidden = f"'BB-{i:05d}'"
        assert forbidden not in section


def test_deterministic(tmp_path):
    p1, p2 = tmp_path / "1.sql", tmp_path / "2.sql"
    orphans.write(p1)
    orphans.write(p2)
    assert p1.read_text() == p2.read_text()
