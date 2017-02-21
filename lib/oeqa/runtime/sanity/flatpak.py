import unittest
from oeqa.oetest import oeRuntimeTest, skipModule
from oeqa.utils.decorators import *

def setUpModule():
    if not oeRuntimeTest.hasFeature('flatpak'):
        skipModule("flatpak not enabled, tests skipped")

class SanityTestFlatpak(oeRuntimeTest):
    '''flatpak sanity tests'''

    #@skipUnlessPassed('test_comm_ssh')
    def test_flatpak_usrmerge(self):
        '''check if / and /usr are properly merged'''
        links = [ '/bin', '/sbin', '/lib', ]
        for l in links:
            (status, output) = self.target.run('readlink %s' % l)
            self.assertEqual(
                status, 0,
                "usrmerge error: %s should be a symbolic link" % l)

    #@skipUnlessPassed('test_comm_ssh')
    def test_ostree_binaries(self):
        '''check if basic ostree binaries exist'''
        binaries = [
            '/usr/bin/ostree',
        ]
        for b in binaries:
            (status, output) = self.target.run('ls %s' % b)
            self.assertEqual(
                status, 0,
                'flatpak (ostree) main binary %s missing' % b)

    #@skipUnlessPassed('test_comm_ssh')
    def test_basic_binaries(self):
        '''check if basic flatpak binaries exist'''
        binaries = [
            '/usr/bin/flatpak',
            '/usr/bin/gpgme-tool',
            '/usr/bin/gpg'
        ]
        for b in binaries:
            (status, output) = self.target.run('ls %s' % b)
            self.assertEqual(
                status, 0,
                'flatpak basic binary %s missing' % b)

    #@skipUnlessPassed('test_comm_ssh')
    def test_session_files(self):
        '''check if flatpak session binaries and service files exist'''
        files = [
            '/usr/bin/flatpak-session',
            '/usr/lib/systemd/system-generators/flatpak-session-enable',
            '/usr/lib/systemd/system/flatpak-fake-runtime.service',
            '/usr/lib/systemd/system/flatpak-update.service',
            '/usr/lib/systemd/system/flatpak-session@.service',
            '/usr/lib/systemd/system/flatpak-sessions.target',
        ]
        for f in files:
            (status, output) = self.target.run('ls %s' % f)
            self.assertEqual(
                status, 0,
                'flatpak session binary/file %s missing' % f)
