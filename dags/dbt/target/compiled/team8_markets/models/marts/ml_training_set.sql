
-- One row per finished game: home side, last pre-game snapshot. Label = home team won.
select *
from `ba882-team8-fall26`.`ai_datasets`.`ml_features`
where is_last_pregame and is_home and team_won is not null