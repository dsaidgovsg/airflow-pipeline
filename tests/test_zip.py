"""
Unit testing of zip_py_module module
"""
import sys
import tempfile

import os
from fncore.utils.zip_py_module import zip_py


def test_zip():
    """Unit test zip_py func that zip is successful"""
    import fncore
    temp_dir = tempfile.gettempdir()
    zipped_file = zip_py(os.path.dirname(fncore.__file__))
    assert zipped_file == os.path.join(temp_dir,
                                       'fn_pyspark_module_fncore.zip')
    sys.path.insert(0, zipped_file)
    reload(fncore)
    assert fncore.__file__ == os.path.join(zipped_file,
                                           'fncore',
                                           '__init__.pyc')
    os.remove(zipped_file)

    import py2neo
    temp_dir = tempfile.gettempdir()
    zipped_file = zip_py(os.path.dirname(py2neo.__file__))
    assert zipped_file == os.path.join(temp_dir,
                                       'fn_pyspark_module_py2neo.zip')
    sys.path.insert(0, zipped_file)
    reload(py2neo)
    assert py2neo.__file__ == os.path.join(zipped_file,
                                           'py2neo',
                                           '__init__.pyc')
    os.remove(zipped_file)
