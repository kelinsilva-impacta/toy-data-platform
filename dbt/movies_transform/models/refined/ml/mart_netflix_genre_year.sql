-- Analise da evolucao dos generos por ano de entrada na Netflix.
-- Grao: um registro por ano de entrada + genero.

with netflix_titles as (

    select
        title_key,
        date_added,
        listed_in
    from {{ ref('int_titles_attributes') }}
    where date_added is not null

),

year_totals as (

    -- Denominador: todos os titulos adicionados naquele ano,
    -- independentemente de possuirem avaliacao no MetaCritic.
    select
        year(date_added) as added_year,
        count(distinct title_key) as total_titles
    from netflix_titles
    group by 1

),

title_genres as (

    -- Um titulo pode pertencer a varios generos.
    -- A expansao cria uma linha por relacionamento titulo-genero.
    select
        n.title_key,
        year(n.date_added) as added_year,
        trim(g.genre) as genre,
        f.rating
    from netflix_titles n
    cross join unnest(split(n.listed_in, ',')) as g(genre)
    left join {{ ref('fct_titles') }} f
        on n.title_key = f.title_key
    where trim(g.genre) <> ''

),

genre_year as (

    select
        added_year,
        genre,
        count(distinct title_key) as title_count,
        count(distinct case
            when rating is not null then title_key
        end) as titles_evaluated,
        avg(rating) as avg_rating
    from title_genres
    group by 1, 2

)

select
    g.added_year,
    g.genre,
    cast(g.added_year as varchar) || '|' || g.genre as genre_year_key,
    g.title_count,
    y.total_titles,
    round(
        100.0 * g.title_count / nullif(y.total_titles, 0),
        2
    ) as catalog_percentage,
    g.titles_evaluated,
    g.avg_rating
from genre_year g
inner join year_totals y
    on g.added_year = y.added_year
