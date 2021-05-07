{
  _config+:: {
    holdings: {
      mysql: {
        port: 3306,
        ip: '10.255.8.249',
      },
      mysql_dev: {
        port: 3306,
        ip: '10.255.10.143'
      },
      schedules: {
        hathifiles: "0 9 * * *",
        concordance: "0 23 * * * ",
      },
      runAs: {
        runAsUser: 1000,
        runAsGroup: 1191,
        fsGroup: 1190
      }
    },
  },

  _images+:: {
    holdings: {
      client: 'hathitrust/holdings-client:latest',
    }
  },

}
