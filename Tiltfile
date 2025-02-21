###################
# LOAD EXTENSIONS #
###################
v1alpha1.extension_repo(name='default', url='https://github.com/tilt-dev/tilt-extensions', ref='HEAD')
load('ext://min_tilt_version', 'min_tilt_version')
load('ext://min_k8s_version', 'min_k8s_version')
load('ext://helm_resource', 'helm_resource', 'helm_repo')
load('ext://helm_remote', 'helm_remote')
load('ext://secret', 'secret_yaml_registry')
###################
min_tilt_version('0.25.0')
min_k8s_version('1.29.0')

# tested with ctlptl create cluster kind --registry=ctlptl-registry
if k8s_context() == 'docker-desktop' or k8s_context() == 'kind-kind':
    k8s_yaml(kustomize('./cluster-resources/local-path-provisioner/'))

    k8s_resource(
      'local-path-provisioner',
      labels=['helpers']
    )

kumomta_dir = os.path.dirname(os.getcwd()) + '/kumomta-k8s-demo'
kumomta_chart_dir = kumomta_dir + '/charts/kumomta'

# This doesn't have to be dragonfly, but dragonfly is easy to setup on k8s and includes the CL_THROTTLE command used by Kumo
helm_remote(
    'dragonfly',
    repo_name = 'oci://ghcr.io/dragonflydb/dragonfly/helm',
    release_name = 'dragonfly',
    namespace = 'default',
    version = "v1.24.0",
    values = [
        '%s/values.local.redis.yaml' % (kumomta_chart_dir),
    ],
)

k8s_resource(
    'dragonfly',
    labels=['redis']
)



# image_registry=read_yaml('%s/values.yaml' % (kumomta_chart_dir))['image']['repository']
helm_values_files = ['%s/values.localdev.yaml' % (kumomta_chart_dir)]

yaml = helm(
    kumomta_chart_dir,
    name='kumomta',
    namespace='default',
	values=helm_values_files,
)
print(yaml)

k8s_yaml(yaml)

k8s_resource(
    'kumomta',
	links=["http://localhost:8080"],
    port_forwards='8000:8000',
    objects=[
        'kumo-configs:configmap',
        'kumomta:serviceaccount',
        'http-listener-keys:secret',
    ],
    resource_deps=['dragonfly'],
    labels=['kumomta']
)
k8s_resource(
    'kumomta-tsa',
	links=["http://localhost:8008"],
    port_forwards='8008:8008',
    objects=[
    ],
    labels=['kumomta']
)

k8s_resource(
    'kumomta-sink',
    objects=[
        'sink-configs:configmap'
    ],
    labels=['kumomta']
)

