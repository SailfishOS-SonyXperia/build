"""A limited version of Cosu's settings classes"""

from typing import Optional, List
import pathlib
import configparser
import re

class CosuMiniSettings(configparser.ConfigParser):
    "Settings parser that reads settings from 'settingsPaths'"
    def __init__(self, settingsPaths: List):
        self.settingsPaths = []
        for path in settingsPaths:
            self.settingsPaths.append(pathlib.Path(path))
        super().__init__(interpolation=None)
        self._loadSettings()

    def _loadSettings(self):
        for path in self.settingsPaths:
            for cfg in path.iterdir():
                with open(cfg, 'r', encoding='utf8') as f:
                    conf_str = f.read()
                self.read_string(conf_str)

    def variable(self, section: str, key: str) -> str:
        "Resolve variable from settings int string"
        return self._resolveString(section, key)
    def _resolveString(self, section: str, key:
                      str, recursion: Optional[int] = 0) -> str:
        max_recursion = 5
        result = key
        if recursion >= max_recursion:
            raise RecursionError
        f_key_re = r'%\([^%]*\)'
        f_key_re_ex = r'%\((.*)\)'
        for f_key in re.finditer(f_key_re, key):
            f_key_ex = re.match(f_key_re_ex, f_key.group(0))
            if f_key_ex is None:
                result.replace(f_key.group(0), "")
            f_key_re_get = self.get(section, f_key_ex.group(1))
            if f_key_re_get.startswith('%('):
                f_key_re_get = self._resolveString(section, f_key_re_get, recursion + 1)
            result = result.replace(f_key.group(0), f_key_re_get)
        return result
