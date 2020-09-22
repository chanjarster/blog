msg="rebuilding site `date`"

site:
	hugo -t noteworthy

deploy: site
	# Go To Public folder
	cd public
	# Add changes to git.
	git add .
	git commit -m "${msg}"
	# Push source and build repos.
	git push origin master
	# Come Back up to the Project Root
	cd ..

.PHONY: site deploy