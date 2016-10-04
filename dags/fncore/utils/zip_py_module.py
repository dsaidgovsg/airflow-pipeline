# coding=utf-8
"""

Zips python module for submission to Spark

"""
import os
# import zipfile
import tempfile
import shutil


# def zip_py(module_dir):
#     """Zips python module for submission to Spark"""
#     if module_dir is None:
#         libpath = os.getcwd()+'/fncore'
#     else:
#         libpath = module_dir
#
#     zippath = '/tmp/fn_pipeline_modules.zip'
#     zipped_file = zipfile.PyZipFile(zippath, mode='w', optimize=0)
#     try:
#         # zf.debug = 3
#         zipped_file.writepy(libpath)
#         return zippath
#     finally:
#         zipped_file.close()

def zip_py(module_dir='fncore'):
    """Zips python module for submission to Spark"""
    root_dir = os.path.abspath(os.path.join(module_dir, os.pardir))
    base_dir = os.path.relpath(module_dir, root_dir)

    temp_dir = tempfile.gettempdir()
    zippath = os.path.join(temp_dir, 'fn_pyspark_module_' + base_dir)

    zipped_file = shutil.make_archive(zippath, 'zip', root_dir, base_dir)
    return zipped_file
