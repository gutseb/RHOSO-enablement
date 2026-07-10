oc patch statefulset openstack-cell1-galera -n openstack --type=json -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/initContainers/0/volumeMounts/-",
    "value": {
      "mountPath": "/etc/pki/tls/certs",
      "name": "certs",
      "readOnly": true
    }
  }
]'


oc patch statefulset openstack-galera -n openstack --type=json -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/initContainers/0/volumeMounts/-",
    "value": {
      "mountPath": "/etc/pki/tls/certs",
      "name": "certs",
      "readOnly": true
    }
  }
]'
