# Configuration file for the Sphinx documentation builder.
#
# For the full list of built-in configuration values, see the documentation:
# https://www.sphinx-doc.org/en/master/usage/configuration.html

# -- Project information -----------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#project-information

project = 'Horse Mod'
copyright = '2025, Horse Team'
author = 'Horse Team'
release = '0.1.0'

# -- General configuration ---------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#general-configuration

extensions = [
    "sphinx_lua_ls"
]

templates_path = ['_templates']
exclude_patterns = []
highlight_language = "lua"


# lua_ls config

lua_ls_project_root = "../../"
lua_ls_backend = "emmylua"
lua_ls_default_options = {
    "require-separator": "/",
    "annotate-require": "always"
}

# -- Options for HTML output -------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#options-for-html-output

html_theme = 'sphinx_rtd_theme'
html_static_path = ['_static']

html_theme_options = {
	"collapse_navigation": False
}
