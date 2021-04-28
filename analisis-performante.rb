# Datos :
#    Generar un archivo que incluya:
#       Unique_identifier
#       Valor de la columna Summary para ese id en EN.csv
#       Valor de la columna Resumen para ese id en en ES.csv
#       Valor de la columna Summary_PT para ese id en PT.csv
require 'csv'

$objeto_traducciones = {}


# Acá voya guardar los faltantes
File.delete("faltantes.csv",) if File.exist?("faltantes.csv",)
$faltantes_csv = CSV.open("faltantes.csv", "a+")
$faltantes_csv << ["Unique_identifier", "Translation", "idioma_symbol", "File Name"]


#Importo archivo Inglés
CSV.foreach("EN-HIV-translations-2020-10-23.csv", :headers => true) do |row|
  id = row["Unique_identifier"]
  if $objeto_traducciones[id]
    raise "Ya existía el registo. Algo raro pasa. El id es #{id} y el objeto que existe es #{$objeto_traducciones[id]}."
  end

  $objeto_traducciones[id] = {en: row["Summary"], es: nil, pt: nil, color: row["Interaction_Status_color"], drug: row["Primary_Drug"], commedication: row["Comedication"]}
end


def importar_traduccion(archivo, nombre_columna, idioma_texto, idioma_symbol)
  CSV.foreach(archivo, :headers => true) do |row|
    id = row["Unique_identifier"]

    if ($objeto_traducciones[id] == nil)
      # Si no existe este ID en el archivo original , pero tenemos una traduccion, significa que se borró!
      if row[nombre_columna]
        $faltantes_csv << [id, row[nombre_columna], idioma_symbol, archivo]
      end
    else
      if $objeto_traducciones[id][idioma_symbol]
        raise "Ya existía la traducción #{idioma_texto} en el registo #{id}. Algo raro pasa."
      end

      $objeto_traducciones[id][idioma_symbol] = row[nombre_columna]
    end
  end
end

## Es importante que por cada idioma se importen en orden de fecha creciente ya una traducción más reciente de un registro existente representa una actualización

# Traducciones primer envío ES
importar_traduccion("Enero/HIV-interactions-2019-03-13 18-05-48-021_TRADUCCION.csv","Resumen", "español", :es)

# Traducciones segundo envío ES
importar_traduccion("Enero/ES_HIV-translations-2020-02-18.csv","Summary_ES", "español", :es)

# Envio final ES
importar_traduccion("Enero/a-traducir-es 6-11-2020.csv","Summary_ES", "español", :es)


###############

#Primer envío traducción PT
importar_traduccion("PT-1 julio 2020.csv","Summary_PT", "portugués", :pt)

#Envíos Gabriela (completo)
importar_traduccion("PT-HIV-translations-2020-02-18.csv","Resumo", "portugués", :pt)

#Envio Eileen
importar_traduccion("Febrero/a-traducir-pt 5_2_2021.xlsx - a-traducir-pt.csv","Summary_PT", "portugués", :pt)
importar_traduccion("ILS-PT-April142021 - ILS-PT-April142021.csv","Summary_PT", "portugués", :pt)

# Genero un objeto traducciones, agrupado por texto en inglés summary
# { summary_en -> { id, es -> listado , pt } }
traducciones_agrupadas = {}
$objeto_traducciones.each do |id, valores|

  if (traducciones_agrupadas[valores[:en]] == nil)
      traducciones_agrupadas[valores[:en]] = {
        ids: [id],
        es: if valores[:es] then [valores[:es]] else [] end,
        pt: if valores[:pt] then [valores[:pt]] else [] end
      }
  else
    # Para español: si hay una traducción nueva para el mismo summary y no la tenía la sumo AL FINAL (importante)
    if (valores[:es] && !traducciones_agrupadas[valores[:en]][:es].include?(valores[:es]))
      traducciones_agrupadas[valores[:en]][:ids] << id
      traducciones_agrupadas[valores[:en]][:es] << valores[:es]
    end

    # Para portugés: si hay una traducción nueva para el mismo summary y no la tenía la sumo AL FINAL (importante)
    if (valores[:pt] && !traducciones_agrupadas[valores[:en]][:pt].include?(valores[:pt]))
      traducciones_agrupadas[valores[:en]][:ids] << id
      traducciones_agrupadas[valores[:en]][:pt] << valores[:pt]
    end
  end
end


File.delete("traducciones-agrupadas.csv",) if File.exist?("traducciones-agrupadas.csv",)
traducciones_agrupadas_csv = CSV.open("traducciones-agrupadas.csv", "a+")
header_agrupadas = ["ingles", "ids", "español", "portugués"]
traducciones_agrupadas_csv << header_agrupadas

traducciones_agrupadas.each do |summary, valores|
  traducciones_agrupadas_csv << [
    summary,
    valores[:ids].join(";"),
    valores[:es].join(";"),
    valores[:pt].join(";")
  ]
end

puts "Cantidad de Summaries (EN) distintos: #{traducciones_agrupadas.size}"
puts  "Cantidad de Summaries con traducción PENDIENTE ES: #{traducciones_agrupadas.select{|k,v| v[:es].count ==0}.size}"
puts  "Cantidad de Summaries con traducción PENDIENTE PT: #{traducciones_agrupadas.select{|k,v| v[:pt].count ==0}.size}"
puts  "Cantidad de Summaries con una sola traducción ES: #{traducciones_agrupadas.select{|k,v| v[:es].count ==1}.size}"
puts  "Cantidad de Summaries con una sola traducción PT: #{traducciones_agrupadas.select{|k,v| v[:pt].count ==1}.size}"
puts  "Cantidad de Summaries con 2 traducciones ES: #{traducciones_agrupadas.select{|k,v| v[:es].count ==2}.size}"
puts  "Cantidad de Summaries con 2 traducciones PT: #{traducciones_agrupadas.select{|k,v| v[:pt].count ==2}.size}"
puts  "Cantidad de Summaries con más de 2 traducciones ES: #{traducciones_agrupadas.select{|k,v| v[:es].count >2}.size}"
puts  "Cantidad de Summaries con más de 2 traducciones PT: #{traducciones_agrupadas.select{|k,v| v[:pt].count >2}.size}"




# Acá voy a guardar los inconsistentes (ie: registros con el mismo texto en ingles que tienen 2 (o más) traducciones diferentes para español o portugues)
File.delete("inconsistentes-es.csv",) if File.exist?("inconsistentes-es.csv")
inconsistencias_es_csv = CSV.open("inconsistentes-es.csv", "a+")
inconsistencias_es_csv << ["Summary_EN", "Lista de Ids", "Lista de Traducciones"]

traducciones_agrupadas.select{|k,v| v[:es].count >1}.each do |id, valores|
  inconsistencias_es_csv << [
    id,
    valores[:ids].join(";"),
    valores[:es].join(";"),
  ]
end

File.delete("inconsistentes-pt.csv",) if File.exist?("inconsistentes-pt.csv")
inconsistencias_pt_csv = CSV.open("inconsistentes-pt.csv", "a+")
inconsistencias_pt_csv << ["Summary_EN", "Lista de Ids", "Lista de Traducciones" ]

traducciones_agrupadas.select{|k,v| v[:pt].count >1}.each do |id, valores|
  inconsistencias_pt_csv << [
    id,
    valores[:ids].join(";"),
    valores[:pt].join(";"),
  ]
end

# A traducir Portugués - Agrupados
File.delete("a-traducir-pt.csv",) if File.exist?("a-traducir-pt.csv")
a_traducir_pt_csv = CSV.open("a-traducir-pt.csv", "a+")
a_traducir_pt_csv << ["Lista_Unique_identifiers", "Summary_EN", "Summary_PT"]


traducciones_agrupadas.select{|k,v| v[:pt].count ==0}.each do |id, valores|
  a_traducir_pt_csv << [
    valores[:ids].join(";"),
    id,
    ""
  ]
end


# A traducir Español - Agrupados
File.delete("a-traducir-es.csv",) if File.exist?("a-traducir-es.csv")
a_traducir_es_csv = CSV.open("a-traducir-es.csv", "a+")
a_traducir_es_csv << ["Lista_Unique_identifiers", "Summary_EN", "Summary_ES"]


traducciones_agrupadas.select{|k,v| v[:es].count ==0}.each do |id, valores|
  a_traducir_es_csv << [
    valores[:ids].join(";"),
    id,
    ""
  ]
end

# Guardo los resultados agrupados completos
File.delete("resultados-performante.csv",) if File.exist?("resultados-performante.csv")
resultados_csv = CSV.open("resultados-performante.csv", "a+")
resultados_header = ["Unique_identifier", "Color", "Primary_Drug", "Comedication", "Summary_EN", "Summary_ES", "Summary_PT"]
resultados_csv << resultados_header


$objeto_traducciones.each do |id, valores|

  if valores[:es]
    traduccion_es = valores[:es]
  else
    traduccion_es = traducciones_agrupadas[valores[:en]][:es].last
  end

  if valores[:pt]
    traduccion_pt = valores[:pt]
  else
    traduccion_pt = traducciones_agrupadas[valores[:en]][:pt].last
  end

  if valores[:en]
    resultados_csv << [
      id,
      valores[:color],
      valores[:drug],
      valores[:commedication],
      valores[:en],
      traduccion_es,
      traduccion_pt,
    ]
  end
end

# Agrego color a las traducciones últimas
# File.delete("Febrero/color-5_2_2021.csv") if File.exist?("Febrero/color-5_2_2021.csv")
# con_color_csv = CSV.open("Febrero/color-5_2_2021.csv", "a+")
# con_color_csv << ["Unique_identifier", "Color","Summary_EN", "Summary_ES"]


# CSV.foreach("Febrero/a-traducir-pt 5_2_2021.xlsx - a-traducir-pt.csv", :headers => true) do |row|
#   id = row["Unique_identifier"]
#   color = $objeto_traducciones[id][:color]
#   con_color_csv << [id, color, row["Summary_EN"], row["Summary_PT"]]
# end








