use Mix.Config

config :tesla, adapter: Tesla.Mock

config :ptolemy,
       :vaults,
       server1: %{
         vault_url: "https://test-vault.com",
         engines: [
           gcp_engine: %{
             engine_type: :GCP,
             engine_path: "gcp/"
           }
         ],
         auth: %{
           method: :GCP,
           credentials: %{
             # fake service account
             gcp_svc_acc:
               "eyJ0eXBlIjogInNlcnZpY2VfYWNjb3VudCIsICJ0b2tlbl91cmkiOiAiaHR0cHM6Ly9hY2NvdW50cy5nb29nbGUuY29tL28vb2F1dGgyL3Rva2VuIiwgInByb2plY3RfaWQiOiJzb21lLWlkLW9mLWEtZmFrZS1wcm9qZWN0IiwgInByaXZhdGVfa2V5X2lkIjogIldIWS1hcmUteW91LXRyeWluZy10by1zdGVhbC10aGlzIiwgInByaXZhdGVfa2V5IjogIi0tLS0tQkVHSU4gUlNBIFBSSVZBVEUgS0VZLS0tLS1cbk1JSUVwQUlCQUFLQ0FRRUFrcXhFU3M3Tnk3cGFadjZFZ0dwZkxzaXFkMXdkY3VDNUV6Vlc2WXZNWUJjekpIZ3VcblZlZDBFejVlTWpTWVFyYUhkemZiQ3pIc1JadzIrVGppRWhMU2RqQ0F6VzJSWTVHNTBXOTYxWDZCN3BGV2VSRkhcbngwNWw5ZDlkRm9GcE5UTDh0SWQxT242YVBVeUgrdnlwbnQzMDB1QWdNQjI1Z3FnVGxMdzczTzk5RTcvenA1Y3dcbjRTNFJtTFM0S1Bsd0psUE9qTnd3TjhraTF3ZWF3M2FkTnVwRWtRL3k4Wnl5aHhCTzVrUG1DenRTN0NDTkloK0tcbmhhVW1aM0x3d2drNkVTRk1LbUtCNDlwaGdRbG0zY1lmaTh1UjBZK3FGWWk1aUhiU21WaXFJaGZLV2xZVStKbkhcbkIvY1NhZW1oOUVxNkw5Ykc4U3h2VjUwYVd3MVBpZkFaUEtMK3VRSURBUUFCQW9JQkFHNkxhNFUrVEprSndPenpcblV3WStKYkxyQnAralM0YXpuSW0vbjl1eHc3MkFmc2t6dThzeEFLa29UbkprZFlXQ2NLTUg5QTJCK09PV0UxRE9cbjhJUlNyMURveVlzSzA1TkoxOVRqd3A1NkZJK3I5cEtVMVpaL25oVXIzY3NDaWpyUVRPbjdWZjFhUWdHRlZzOXhcbjhwMk1CK09QakhMM1ZFUUhUWXJDUEJRT1pDU25XS2tmZGRHYlJoNTF1SllxUmNhTU5lSnVNRkRyVmVCSDIyY2lcbmJraDh6ZSs0NGNGeTVBWG5NUmprODdQY0c4dXZrWXZDMXRONWNhSjEwcjRkNFQxRm42UVFQeUdvRkRnZnc4c2Rcbmt4R3BiSjBaY2pRZXNzUFVhWVpGRFlTMGVnQkxUbmNJTktheG8wbHlscGdHR3BhSVJlSG8waURvN2ZrUmpGcURcbkg5Qms4Z0VDZ1lFQTBJMlEraE4xbXViYkhtUm83NHQ3blFIU3ZRSVMxd2tPYzRMbDFjbXdta0s1R0I3Rm1qYXJcbjRSbWhMTEQvUmthWjJtUTBFTDUyK3EvOXF6Y0MrTzRNUHlVQ2RGU2RkVThXbExvb003dFZtWERoako0UU5IcjBcbnhWYmRhN0Nnc1V2S0dibHlvWEVVWVFlcEVWdkdDTVROYXplM2I4OENPZGFLclY3dmZPRVhFR0VDZ1lFQXRBcTJcbnJ4OVFLb1RpZlN0dHRJcjBQWjJoNmd2SThKUWlhUUd5NTlzZ1hFMUp3VjBuNWRiejM2cFY1QkNtWWIvZVYvYVFcbjVkUG9iM2VHazNZNlRibXVGWldxVmxaTnZJQjFPSTZ2ejYrWlpnWEltbGY4VmJzZHFmd0ltZVBjUUo1U1d0NHRcbjBFYU01WXhqbndXRkN0UXBDenYvaGpjMVpKWU5LYXJOanUvRmJWa0NnWUFXcVJzMG9RS3BWeVk5OGlrWXhpNGpcblREeHF2eHZ1ODVQM1p5UzBDeHMrVjd1bTdFa0tUYUIxY0FSOFI2c2xKcXkyOXlaVkgyenNKazFJMmt4ZllmWkFcbnNqUEhFaDZkelg4bG4raVlYbVdacTVOR1pUSmJrWFNoTUtRVWZIZXBiQlBFb2NyYjBkNm1BR0FWZThSVDFaYUFcbmJPaG9wTFNZTmtDUlAveUR0QzErWVFLQmdRQ1d5NTVsSVBuNUV1SE1hdEp3OUMxTGFqclNGOXJPUFpSd2xONnVcbnVXYnFTRVd0TWdRWHlxanFQZlhBbG4xMHc4cExySldDR2JIRm9ydlJ5S1Zlc2xWdmVMSjVxOEZpVDhsZWZJd2VcbmpIb1Q3R1l2ZCtBK1FnRy9mUHdMUU1FYVVrQ3lJUU1JUGY4R3lFWXNTK2c1d0tjNzVKM0pZWFpUOENYSUwyb0pcbi9TTkR5UUtCZ1FDMXF5Q2pwVlI1VHRNbHorSGdLajhDUnNmWTliM0NUemZIekVIT3V0YlVHODMwWnE1RlBNTFZcbnd3T29ISDVYQWVTQUtpTDZXdnlDazdzdlRNQ25NcXpWbldyd1pmdlhjV0lUMzhkclFTUHdtZ1R5dEdXZ2FVeDlcbnUwWU9NbWNMK2NkTlpBN3pKSEYwQWNaVVNJNW9FaU9IYVlrMjZ2dWplZ2ZFeEVubWdYNVR3UT09XG4tLS0tLUVORCBSU0EgUFJJVkFURSBLRVktLS0tLVxuIiwgImNsaWVudF94NTA5X2NlcnRfdXJsIjogImh0dHBzOi8vd3d3Lmdvb2dsZWFwaXMuY29tL2RvbnQvYm90aGVyL2JvdHMvYmVjdWFzZS90aGlzLWlzLWEtZmFrZS1zdmMtYWNjQHByb2plY3QtaWQuaWFtLmdzZXJ2aWNlYWNjb3VudC5jb20iLCAiY2xpZW50X2lkIjogIjEyMzQ1Njc4OSIsICJjbGllbnRfZW1haWwiOiAidGhpcy1pcy1hLWZha2Utc3ZjLWFjY0Bwcm9qZWN0LWlkLmlhbS5nc2VydmljZWFjY291bnQuY29tIiwgImF1dGhfdXJpIjogImh0dHBzOi8vYWNjb3VudHMuZ29vZ2xlLmNvbS9vL29hdXRoMi9hdXRoIiwgImF1dGhfcHJvdmlkZXJfeDUwOV9jZXJ0X3VybCI6ICJodHRwczovL3d3dy5nb29nbGVhcGlzLmNvbS9vYXV0aDIvdjEvY2VydHMifQ==",
             vault_role: "write-role",
             exp: 900
           },
           auto_renew: true,
           opts: [
             iap_svc_acc: :reuse,
             client_id: "asasd229384sdhjff9efhbe234FAKE.apps.googleusercontent.com",
             exp: 900
           ]
         }
       },
       server2: %{
         vault_url: "https://test-vault.com",
         engines: [
           kv_engine1: %{
             engine_type: :KV,
             engine_path: "secret/",
             secrets: %{
               test_secret: "/test_secret"
             }
           },
           gcp_engine1: %{
             engine_type: :GCP,
             engine_path: "gcp/"
           },
           pki_engine1: %{
             engine_type: :PKI,
             engine_path: "pki/",
             roles: %{
               test_role1: "/role1"
             }
           }
         ],
         auth: %{
           method: :Approle,
           credentials: %{
             role_id: "test",
             secret_id: "test"
           },
           auto_renew: true,
           opts: []
         }
       }

config :ptolemy, cache: CacheMock
