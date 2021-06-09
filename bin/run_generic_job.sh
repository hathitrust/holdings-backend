#!/bin/bash

SUFFIX=$1
shift
ARGS=$(perl -e 'print "[ \"", join("\", \"",@ARGV), "\"]"' "$@")
kubectl -n holdings create -f - <<EOT
apiVersion: batch/v1
kind: Job
metadata:
  name: holdings-client-${SUFFIX}
  namespace: holdings
spec:
  template:
    spec:
      containers:
      - command: ${ARGS}
        env:
        - name: MONGODB_PASSWORD
          valueFrom:
            secretKeyRef:
              key: mongodb-password
              name: holdings-mongodb
        - name: MYSQL_PASSWORD
          valueFrom:
            secretKeyRef:
              key: mysql-password
              name: holdings-mysql
        - name: MONGOID_ENV
          value: production
        - name: TZ
          value: America/Detroit
        image: ghcr.io/hathitrust/holdings/client-unstable:latest
        imagePullPolicy: Always
        name: holdings-client
        volumeMounts:
        - mountPath: /htapps
          name: htapps
        - mountPath: /htapps-dev
          name: htapps-dev
        - mountPath: /usr/src/app/config/settings/production.local.yml
          name: holdings-config
          subPath: production.local.yml
        - mountPath: /usr/src/app/config/large_cluster_ocns.txt
          name: large-cluster-ocns
          subPath: large_cluster_ocns.txt
        - mountPath: /htprep
          name: htprep
      restartPolicy: OnFailure
      securityContext:
        fsGroup: 1190
        runAsGroup: 1191
        runAsUser: 1000
      volumes:
      - name: htapps
        nfs:
          path: /ifs/htapps
          server: nas-macc.sc.umdl.umich.edu
      - name: htapps-dev
        nfs:
          path: /htdev/htapps
          server: htdev.value.storage.umich.edu
      - configMap:
          name: holdings-config
        name: holdings-config
      - configMap:
          name: large-cluster-ocns
        name: large-cluster-ocns
      - name: htprep
        nfs:
          path: /ifs/htprep
          server: nas-macc.sc.umdl.umich.edu
EOT
