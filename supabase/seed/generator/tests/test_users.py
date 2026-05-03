from pathlib import Path

import pytest
from generator import users, config


@pytest.fixture
def out_path(tmp_path):
    return tmp_path / "02b_users.sql"


def test_user_count(out_path):
    users.write(out_path)
    text = out_path.read_text()
    section = text.split("-- users: ")[1].split("\n\n")[0]
    rows = [ln for ln in section.splitlines() if ln.startswith("  (")]
    assert len(rows) == config.CARDINALITIES["users"]["users"]


def test_address_count(out_path):
    users.write(out_path)
    text = out_path.read_text()
    section = text.split("-- addresses: ")[1].split("\n\n")[0]
    rows = [ln for ln in section.splitlines() if ln.startswith("  (")]
    assert len(rows) == config.CARDINALITIES["users"]["addresses"]


def test_phones_dont_collide_with_smoke(out_path):
    users.write(out_path)
    text = out_path.read_text()
    # Smoke uses +919812340001..+919812340005
    for i in range(1, 6):
        smoke_phone = f"+9198123400{i:02d}"
        assert smoke_phone not in text


def test_deterministic(tmp_path):
    p1, p2 = tmp_path / "1.sql", tmp_path / "2.sql"
    users.write(p1)
    users.write(p2)
    assert p1.read_text() == p2.read_text()
