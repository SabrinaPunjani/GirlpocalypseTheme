import csv


# Print Relics
print("""ECS.Relics = {""")

with open('relics.csv') as f:
	reader = csv.DictReader(f)
	for row in reader:
		print(r"""	{""")
		print(r"""		id=%s,""" % row['relics_id'])
		print(r"""		name="%s",""" % row["relics_name"])
		print(r"""		desc="%s",""" % row["relics_description"])
		print(r"""		effect="%s",""" % row["relics_properties"])
		print(r"""		is_consumable=%s,""" % ("false" if row["relics_consumable"] == "0" else "true"))
		print(r"""		is_marathon=%s,""" % ("false" if row["relics_portion"] == "0" else "true"))
		print(r"""		img="%s",""" % row["relics_imageurl"])
		print(r"""		action=function(relics_used) end,""")
		print(r"""		score=function(ecs_player, song_info, song_data, relics_used, ap, score)""")
		print(r"""			return 0""")
		print(r"""		end,""")
		print(r"""	},""")
print(r"""}""")