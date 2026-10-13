enum LogInResult {
  logged,
  error_wrong_credentials,
  error_not_fully_setupped,
  error_unknown,
  account_disattivato,   // credenziali giuste, ma l'account è disattivato: si chiede se riattivarlo
}
