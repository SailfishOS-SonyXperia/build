# -*- python3 -*-
"""Shared functions and classes to be used in our build scripts"""

from typing import Dict, Union, List, Iterable, Optional
import logging
from pathlib import Path
import configparser
import argparse
import osc.core
self_dir = Path(__file__).parent

def ParseEnvfile() -> configparser.ConfigParser:
    "Read environment file and return configparser object"
    envfile= self_dir / "shared.env"
    if not envfile.exists:
        logging.error("Env file {file} doesn't exist", file=envfile)
        raise FileNotFoundError

    with open(envfile, 'r', encoding='utf8') as f:
        conf_str = '[dummy]\n' + f.read()

    env_conf = configparser.ConfigParser()
    env_conf.read_string(conf_str)

    return env_conf['dummy']


def SharedArgParse(prog: str, description : str) -> argparse.ArgumentParser:
    "Create argparse parser with shared arguments already loaded in"
    parser = argparse.ArgumentParser(prog = prog,
                                     description = description,
                                     epilog='')
    parser.add_argument('-A', "--apiurl", dest = "apiurl",
                        required= False,
                        help = "API url to the target obs, defaults to $obs_api_url")

    return parser


def PrjMetaToDict(data: Union[bytes, list, Iterable])  -> Dict:
    # pylint: disable=too-many-statements, too-many-branches
    "Turn Project configuration into a dictionary"
    prjConfDict = {
        "Macros":{}
    }
    if isinstance(data, bytes) or not isinstance(data, list):
        #data = osc.core.decode_it(data)
        return False
    data = osc.core.decode_list(data)
    macros = False
    multiline = False
    key = False
    skey = False
    define = False
    for line in data:
        if not multiline and line.startswith('#'):
            continue
        count = None
        if define:
            macros = False
            define = False
        if not macros:
            key = False
        if not multiline:
            skey = False
        if multiline:
            multiline = False
        words = line.split(' ')
        for word in words:
            word = word.removesuffix('\n')
            if not word:
                continue
            if word.endswith('\\'):
                multiline = True
                word = word.removesuffix('\\')
            if macros:
                if not skey:
                    skey = word.removeprefix('%')
                    if define:
                        prjConfDict["Macros"][skey] = ""
                    else:
                        prjConfDict["Macros"][skey] = []
                    continue
                if define:
                    prjConfDict["Macros"][skey] += " " + word
                    prjConfDict["Macros"][skey] = \
                        prjConfDict["Macros"][skey].removeprefix(" ")
                else:
                    prjConfDict["Macros"][skey].append(word)
                continue
            if not key and not count:
                count = 1
                if word.endswith(':'):
                    key = word.removesuffix(':')
                if word == "%define":
                    key = "Macros"
                    define = True
                if key == "Macros":
                    macros = True
                continue
            if key not in prjConfDict:
                prjConfDict[key] = []
            prjConfDict[key].append(word)
    return prjConfDict



def PrjConf(path_args: List, apiurl: str) -> Dict:
    "Wrapper around osc.core to fetch project configuration"
    meta = osc.core.meta_exists(metatype = "prjconf",
                          path_args = (path_args, ),
                          apiurl = apiurl)
    return PrjMetaToDict(meta)


def GetConfig(overrideList: Dict) -> osc.conf.Options:
    "Wrapper to initialize the osc module for all our scripts"
    config = osc.conf.Options()
    osc.conf.get_config(**overrideList)

    return config
