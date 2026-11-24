-- fails if any row was captured after tip-off (leakage)
select * from `ba882-team8-fall26`.`ai_datasets`.`ml_features`
where snapshot_hour >= commence_ts