c = get_config()  # noqa: F821
c.NotebookApp.ip = '0.0.0.0'
c.NotebookApp.port = 8894
c.NotebookApp.open_browser = False
c.NotebookApp.password = ''
c.NotebookApp.password_required = False
c.NotebookApp.root_dir = '/example/example'

## Whether to allow the user to run the notebook as root.
c.NotebookApp.allow_root = True
