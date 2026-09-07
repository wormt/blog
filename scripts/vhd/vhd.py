import logging

import osbuild

LOGGER = logging.getLogger(__name__)


def main() -> None:
    """Log the OSBuild version"""
    logging.basicConfig(format='%(message)s', level=logging.INFO)
    LOGGER.info('osbuild %s', osbuild.__version__)


if __name__ == '__main__':
    main()
