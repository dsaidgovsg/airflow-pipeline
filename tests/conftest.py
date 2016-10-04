# coding=utf-8
"""
Setting up py.text fixtures
"""

import pytest
from fncore.specs import dummy_graph_spec as dummy


@pytest.fixture(scope='module')
def dummy_graph_spec():
    """Module level fixture for a dummy graph specification"""
    return dummy.GRAPH_SPECIFICATION
