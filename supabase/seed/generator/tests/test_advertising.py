import re
from pathlib import Path

import pytest
from generator import advertising, config


@pytest.fixture
def out_path(tmp_path):
    return tmp_path / "02f_advertising.sql"


def test_impressions_count(out_path):
    advertising.write(out_path)
    text = out_path.read_text()
    section = text.split("-- ad_impressions: ")[1].split("\n\n")[0]
    rows = [ln for ln in section.splitlines() if ln.startswith("  (")]
    target = config.CARDINALITIES["advertising"]["ad_impressions"]
    assert abs(len(rows) - target) <= int(target * 0.02)


def test_clicks_about_10pct_of_impressions(out_path):
    advertising.write(out_path)
    text = out_path.read_text()
    imp_section = text.split("-- ad_impressions: ")[1].split("\n\n")[0]
    click_section = text.split("-- ad_clicks: ")[1].split("\n\n")[0]
    n_imp = sum(1 for ln in imp_section.splitlines() if ln.startswith("  ("))
    n_click = sum(1 for ln in click_section.splitlines() if ln.startswith("  ("))
    ctr = n_click / n_imp
    assert 0.08 <= ctr <= 0.12


def test_attribution_models_present(out_path):
    advertising.write(out_path)
    text = out_path.read_text()
    section = text.split("-- ad_attributions: ")[1].split("\n\n")[0]
    assert "'last_click'" in section
    assert "'view_through'" in section
    assert "'multi_touch_linear'" in section


def test_attribution_total_count(out_path):
    advertising.write(out_path)
    text = out_path.read_text()
    section = text.split("-- ad_attributions: ")[1].split("\n\n")[0]
    rows = [ln for ln in section.splitlines() if ln.startswith("  (")]
    target = config.CARDINALITIES["advertising"]["ad_attributions"]
    assert abs(len(rows) - target) <= int(target * 0.05)


def test_deterministic(tmp_path):
    p1, p2 = tmp_path / "1.sql", tmp_path / "2.sql"
    advertising.write(p1)
    advertising.write(p2)
    assert p1.read_text() == p2.read_text()
